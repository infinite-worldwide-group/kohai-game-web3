# frozen_string_literal: true

# Background job to monitor incoming Solana transactions
# Automatically processes payments made via QR codes
class PaymentMonitorJob < ApplicationJob
  queue_as :default

  # Run this job every 30 seconds to check for new payments
  # In production, use a scheduler like Sidekiq-cron or whenever gem
  def perform
    platform_wallet = ENV.fetch('PLATFORM_WALLET_ADDRESS')

    Rails.logger.info "[PaymentMonitor] Checking for new transactions to #{platform_wallet}"

    # Fetch recent incoming transactions
    recent_txs = SolanaTransactionService.fetch_incoming_transactions(
      wallet_address: platform_wallet,
      limit: 50 # Check last 50 transactions
    )

    Rails.logger.info "[PaymentMonitor] Found #{recent_txs.size} incoming transactions"

    processed_count = 0
    recent_txs.each do |tx|
      result = process_transaction(tx)
      processed_count += 1 if result
    end

    Rails.logger.info "[PaymentMonitor] Processed #{processed_count} new payments"
  end

  private

  def process_transaction(tx)
    # Skip if already processed
    if CryptoTransaction.exists?(transaction_signature: tx[:signature])
      Rails.logger.debug "[PaymentMonitor] Skipping duplicate transaction: #{tx[:signature]}"
      return false
    end

    # Extract order number from memo
    memo = tx[:memo]
    unless memo.present?
      Rails.logger.warn "[PaymentMonitor] Transaction #{tx[:signature]} has no memo, skipping"
      return false
    end

    # Find order by order number in memo
    # Memo format should be the order number: "ORD-1234567890-ABCD"
    order = Order.find_by(order_number: memo.strip, status: 'pending_payment')

    unless order
      Rails.logger.warn "[PaymentMonitor] No pending order found for memo: #{memo}"
      return false
    end

    # Verify amount matches (allow small tolerance)
    expected_amount = order.amount.to_f
    actual_amount = tx[:amount]
    tolerance = 0.0001

    if (actual_amount - expected_amount).abs > tolerance
      Rails.logger.error "[PaymentMonitor] Amount mismatch for order #{order.order_number}: expected #{expected_amount}, got #{actual_amount}"
      return false
    end

    # Process the payment
    begin
      ActiveRecord::Base.transaction do
        # Create crypto transaction record
        crypto_tx = CryptoTransaction.create!(
          order: order,
          transaction_signature: tx[:signature],
          wallet_from: tx[:from_address],
          wallet_to: tx[:to_address],
          amount: tx[:amount],
          token: 'SOL',
          network: 'solana',
          decimals: 9,
          transaction_type: 'payment',
          direction: 'inbound',
          state: 'confirmed',
          confirmations: tx[:confirmations],
          block_timestamp: tx[:block_timestamp] ? Time.at(tx[:block_timestamp]) : nil,
          verified_at: Time.current
        )

        # Update order status
        order.pay!

        # Link order to user if wallet is recognized
        if order.user_id.nil?
          user = User.find_by(wallet_address: tx[:from_address])
          if user
            order.update!(user: user)
            Rails.logger.info "[PaymentMonitor] Linked anonymous order #{order.order_number} to user #{user.id}"
          end
        end

        # Create audit log
        AuditLog.create!(
          user: order.user,
          action: 'qr_payment_received',
          auditable: order,
          metadata: {
            order_number: order.order_number,
            transaction_signature: tx[:signature],
            wallet_from: tx[:from_address],
            amount: tx[:amount],
            memo: memo
          }
        )

        Rails.logger.info "[PaymentMonitor] Successfully processed payment for order #{order.order_number}"

        # TODO: Enqueue vendor fulfillment job
        # VendorFulfillmentJob.perform_later(order.id)
      end

      true
    rescue StandardError => e
      Rails.logger.error "[PaymentMonitor] Error processing transaction #{tx[:signature]}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
end
