# frozen_string_literal: true

# Background job to check status of processing orders from vendor API
# This job runs periodically to update orders that are stuck in processing state
class CheckProcessingOrdersJob < ApplicationJob
  queue_as :default

  # Check all processing orders and update their status based on vendor API
  def perform
    Rails.logger.info("CheckProcessingOrdersJob: Starting to check processing orders")

    # Find all orders in processing state that have tracking_number and crypto_transaction
    processing_orders = Order.where(status: 'processing')
                              .where.not(tracking_number: nil)
                              .joins(:crypto_transaction)
                              .order(updated_at: :asc)
                              .limit(50) # Process max 50 orders at a time

    if processing_orders.empty?
      Rails.logger.info("CheckProcessingOrdersJob: No processing orders to check")
      return
    end

    Rails.logger.info("CheckProcessingOrdersJob: Found #{processing_orders.count} orders to check")

    checked_count = 0
    updated_count = 0
    error_count = 0

    processing_orders.each do |order|
      begin
        checked_count += 1
        updated = order.check_vendor_status

        if updated
          updated_count += 1
          Rails.logger.info("CheckProcessingOrdersJob: Order #{order.order_number} status updated to #{order.status}")
        end

      rescue => e
        error_count += 1
        Rails.logger.error("CheckProcessingOrdersJob: Error checking order #{order.order_number}: #{e.message}")
      end

      # Add a small delay between API calls to avoid rate limiting
      sleep(0.5)
    end

    Rails.logger.info("CheckProcessingOrdersJob: Completed - Checked: #{checked_count}, Updated: #{updated_count}, Errors: #{error_count}")
  end
end
