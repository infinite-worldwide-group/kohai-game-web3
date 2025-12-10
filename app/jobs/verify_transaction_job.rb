class VerifyTransactionJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    crypto_tx = order.crypto_transaction

    return if crypto_tx.blank?
    return if crypto_tx.state == 'confirmed' # Already verified

    tx_signature = crypto_tx.transaction_signature
    platform_wallet = ENV.fetch("SOLANA_PLATFORM_WALLET_ADDRESS")
    user_wallet = order.user.wallet_address

    Rails.logger.info "=" * 80
    Rails.logger.info "VERIFY TRANSACTION JOB - Starting verification"
    Rails.logger.info "Order: #{order.order_number}"
    Rails.logger.info "Transaction Signature: #{tx_signature}"
    Rails.logger.info "Platform Wallet: #{platform_wallet}"
    Rails.logger.info "User Wallet: #{user_wallet}"
    Rails.logger.info "Expected Amount: #{order.crypto_amount} #{order.crypto_currency}"
    Rails.logger.info "=" * 80

    begin
      # Verify transaction on blockchain
      transaction_details = SolanaTransactionService.verify_transaction(
        signature: tx_signature,
        expected_amount: order.crypto_amount,
        expected_receiver: platform_wallet,
        expected_sender: user_wallet,
        token: order.crypto_currency # Pass token type (USDT, USDC, SOL)
      )

      # Update crypto transaction with verified details
      crypto_tx.update!(
        state: 'confirmed',
        confirmations: transaction_details[:confirmations],
        block_number: transaction_details[:block_number],
        block_timestamp: transaction_details[:block_timestamp] ? Time.at(transaction_details[:block_timestamp]) : nil,
        gas_fee: transaction_details[:fee_lamports] ? transaction_details[:fee_lamports].to_f / 1_000_000_000 : nil,
        verified_at: Time.current
      )

      # Update order status to paid
      order.pay! if order.pending?

      Rails.logger.info "Transaction verified successfully for order #{order.order_number}"

    rescue SolanaTransactionService::TransactionNotFound => e
      Rails.logger.error "Transaction not found: #{e.message}"
      order.update(error_message: "Transaction not found on blockchain. Please ensure the transaction is confirmed.")
      order.fail!

    rescue SolanaTransactionService::InvalidTransaction => e
      Rails.logger.error "Invalid transaction: #{e.message}"
      crypto_tx.update(state: 'failed')
      order.update(error_message: e.message)
      order.fail!

    rescue StandardError => e
      Rails.logger.error "Error verifying transaction: #{e.message}\n#{e.backtrace.join("\n")}"
      order.update(error_message: "Error verifying transaction: #{e.message}")
      order.fail!
    end
  end
end
