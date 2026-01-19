# frozen_string_literal: true

module Api
  class VendorController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    # POST /api/vendor/callback
    # Callback endpoint for vendor to update order status
    #
    # Expected headers:
    #   X-Callback-Key: <callback_key>
    #
    # Expected body:
    # {
    #   "reference": "order_number",
    #   "status": "succeeded|failed|processing|pending",
    #   "invoiceId": "vendor_invoice_id",
    #   "trxDate": "transaction_date",
    #   "sn": "serial_number"
    # }
    def callback
      # Validate callback key
      callback_key = request.headers['X-Callback-Key']
      expected_key = ENV['VENDOR_CALLBACK_KEY']

      if expected_key.present? && callback_key != expected_key
        Rails.logger.warn("Vendor callback: Invalid callback key")
        render json: { success: false, error: "Unauthorized" }, status: :unauthorized
        return
      end

      # Parse callback data
      reference = params[:reference]
      status = params[:status]&.downcase
      tracking_number = params[:invoiceId]  # Vendor's invoiceId is our tracking_number
      trx_date = params[:trxDate]
      sn = params[:sn]

      Rails.logger.info("Vendor callback received: reference=#{reference}, status=#{status}, tracking=#{tracking_number}, sn=#{sn}")

      # Find order by reference (order_number)
      order = Order.find_by(order_number: reference)

      unless order
        Rails.logger.error("Vendor callback: Order not found for reference #{reference}")
        render json: { success: false, error: "Order not found" }, status: :not_found
        return
      end

      # Log the callback
      order.vendor_transaction_logs.create!(
        vendor_name: 'callback',
        request_body: params.to_json,
        response_body: nil,
        status: status,
        executed_at: Time.current
      )

      # Update order based on status
      begin
        case status
        when 'succeeded', 'success', 'completed'
          # Update tracking_number and sn if provided
          order.update!(
            tracking_number: tracking_number.presence || order.tracking_number,
            metadata: {
              sn: sn,
              trx_date: trx_date,
              callback_received_at: Time.current.iso8601
            }.to_json
          )
          order.success! if order.may_success?
          Rails.logger.info("Vendor callback: Order #{reference} marked as succeeded")

        when 'failed', 'error', 'cancelled'
          order.update!(
            tracking_number: tracking_number.presence || order.tracking_number,
            error_message: "Vendor order #{status}: #{params[:message] || params[:errorMessage] || 'Unknown error'}",
            metadata: {
              sn: sn,
              trx_date: trx_date,
              callback_received_at: Time.current.iso8601
            }.to_json
          )
          order.fail! if order.may_fail?
          Rails.logger.info("Vendor callback: Order #{reference} marked as failed")

        when 'processing', 'pending'
          # Update tracking_number if provided but keep processing
          if tracking_number.present?
            order.update!(tracking_number: tracking_number)
          end
          Rails.logger.info("Vendor callback: Order #{reference} still processing")

        else
          Rails.logger.warn("Vendor callback: Unknown status '#{status}' for order #{reference}")
        end

        render json: { success: true, message: "Order updated" }, status: :ok

      rescue AASM::InvalidTransition => e
        Rails.logger.warn("Vendor callback: Invalid state transition for order #{reference}: #{e.message}")
        render json: { success: true, message: "Order already in final state" }, status: :ok

      rescue => e
        Rails.logger.error("Vendor callback: Error updating order #{reference}: #{e.message}")
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
