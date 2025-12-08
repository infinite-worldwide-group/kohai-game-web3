# frozen_string_literal: true

module Mutations
  module Orders
    class ConfirmPayment < Mutations::BaseMutation
      description 'Confirm payment for an order by verifying the Solana transaction'

      argument :order_id, ID, required: true, description: 'Order ID'
      argument :transaction_signature, String, required: true, description: 'Solana transaction signature'

      field :order, Types::OrderType, null: true
      field :crypto_transaction, Types::CryptoTransactionType, null: true
      field :verified, Boolean, null: false
      field :errors, [String], null: false

      def resolve(order_id:, transaction_signature:)
        authenticate_user!

        # Find the order
        order = current_user.orders.find_by(id: order_id)
        return respond_error("Order not found") unless order

        # Get sender wallet from current user
        sender_wallet = current_user.wallet_address

        # Verify and confirm the payment
        result = PaymentVerificationService.verify_and_confirm_payment(
          order: order,
          transaction_signature: transaction_signature,
          sender_wallet: sender_wallet
        )

        if result[:success]
          {
            order: result[:order],
            crypto_transaction: result[:crypto_transaction],
            verified: true,
            errors: []
          }
        else
          {
            order: order,
            crypto_transaction: nil,
            verified: false,
            errors: [result[:error]]
          }
        end

      rescue ActiveRecord::RecordNotFound => e
        respond_error("Order not found")
      rescue StandardError => e
        Rails.logger.error "Payment confirmation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        respond_error("Error confirming payment: #{e.message}")
      end

      private

      def respond_error(message)
        {
          order: nil,
          crypto_transaction: nil,
          verified: false,
          errors: [message]
        }
      end
    end
  end
end
