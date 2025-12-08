# frozen_string_literal: true

# Service to verify Solana payments before confirming orders
module PaymentVerificationService
  extend self

  # Verify a payment transaction before confirming the order
  # @param order [Order] The order to verify payment for
  # @param transaction_signature [String] The Solana transaction signature
  # @param sender_wallet [String] The wallet that sent the payment
  # @return [Hash] Verification result with success status and data/error
  def verify_payment(order:, transaction_signature:, sender_wallet:)
    begin
      # Validate inputs
      return error_response("Order not found") unless order.present?
      return error_response("Transaction signature is required") unless transaction_signature.present?
      return error_response("Sender wallet is required") unless sender_wallet.present?

      # Check if order is in correct state
      unless order.status == 'pending'
        return error_response("Order is not pending (current status: #{order.status})")
      end

      # Get expected values - strip whitespace to prevent comparison issues
      platform_wallet = ENV.fetch('PLATFORM_WALLET_ADDRESS').strip
      sender_wallet_clean = sender_wallet.to_s.strip
      expected_amount = BigDecimal(order.crypto_amount.to_s)  # Use BigDecimal for precision
      expected_currency = order.crypto_currency || 'SOL'

      Rails.logger.info "Verifying payment for order #{order.order_number}"
      Rails.logger.info "  Expected amount: #{expected_amount} #{expected_currency}"
      Rails.logger.info "  Expected receiver: #{platform_wallet}"
      Rails.logger.info "  Sender wallet: #{sender_wallet_clean}"
      Rails.logger.info "  Transaction: #{transaction_signature}"

      # Verify transaction on Solana blockchain
      tx_details = SolanaTransactionService.verify_transaction(
        signature: transaction_signature,
        expected_amount: expected_amount.to_f,  # Convert to float for service
        expected_receiver: platform_wallet,
        expected_sender: sender_wallet_clean
      )

      # Transaction verified successfully
      Rails.logger.info "✓ Transaction verified successfully"
      Rails.logger.info "  Amount: #{tx_details[:amount]} #{expected_currency}"
      Rails.logger.info "  From: #{tx_details[:from_address]}"
      Rails.logger.info "  To: #{tx_details[:to_address]}"
      Rails.logger.info "  Status: #{tx_details[:status]}"

      success_response(
        verified: true,
        transaction_details: tx_details,
        order: order,
        message: "Payment verified successfully"
      )

    rescue SolanaTransactionService::TransactionNotFound => e
      Rails.logger.error "Transaction not found: #{e.message}"
      error_response("Transaction not found on blockchain. Please wait a moment and try again.")

    rescue SolanaTransactionService::InsufficientConfirmations => e
      Rails.logger.error "Insufficient confirmations: #{e.message}"
      error_response("Transaction is not yet confirmed. Please wait a moment and try again.")

    rescue SolanaTransactionService::InvalidTransaction => e
      Rails.logger.error "Invalid transaction: #{e.message}"
      error_response("Transaction verification failed: #{e.message}")

    rescue StandardError => e
      Rails.logger.error "Payment verification error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      error_response("Error verifying payment: #{e.message}")
    end
  end

  # Verify payment and create crypto transaction record
  # @param order [Order] The order to verify payment for
  # @param transaction_signature [String] The Solana transaction signature
  # @param sender_wallet [String] The wallet that sent the payment
  # @return [Hash] Result with success status and crypto_transaction
  def verify_and_record_payment(order:, transaction_signature:, sender_wallet:)
    # First verify the payment
    verification = verify_payment(
      order: order,
      transaction_signature: transaction_signature,
      sender_wallet: sender_wallet
    )

    return verification unless verification[:success]

    # Check if transaction already recorded
    existing_tx = CryptoTransaction.find_by(transaction_signature: transaction_signature)
    if existing_tx
      Rails.logger.warn "Transaction #{transaction_signature} already recorded"
      return error_response("This transaction has already been used for another order")
    end

    # Check if order already has a payment
    if order.crypto_transaction.present?
      Rails.logger.warn "Order #{order.order_number} already has a payment"
      return error_response("This order already has a payment recorded")
    end

    # Create crypto transaction record
    tx_details = verification[:transaction_details]

    # Use BigDecimal for amount to preserve precision
    transaction_amount = BigDecimal(tx_details[:amount].to_s)
    gas_fee = BigDecimal((tx_details[:fee_lamports].to_f / 1_000_000_000).to_s)

    crypto_tx = CryptoTransaction.create!(
      order: order,
      transaction_signature: transaction_signature,
      wallet_from: tx_details[:from_address],
      wallet_to: tx_details[:to_address],
      amount: transaction_amount,
      token: 'SOL',
      network: 'solana',
      decimals: 9,
      transaction_type: 'payment',
      direction: 'inbound',
      state: 'confirmed',
      confirmations: tx_details[:confirmations],
      block_number: tx_details[:block_number],
      block_timestamp: tx_details[:block_timestamp] ? Time.at(tx_details[:block_timestamp]) : nil,
      gas_fee: gas_fee,
      verified_at: Time.current
    )

    # Create audit log
    AuditLog.create!(
      user: order.user,
      action: 'payment_verified',
      auditable: order,
      metadata: {
        order_number: order.order_number,
        transaction_signature: transaction_signature,
        wallet_from: tx_details[:from_address],
        wallet_to: tx_details[:to_address],
        amount: tx_details[:amount],
        verified_at: Time.current
      }
    )

    Rails.logger.info "✓ Payment recorded for order #{order.order_number}"

    success_response(
      verified: true,
      crypto_transaction: crypto_tx,
      transaction_details: tx_details,
      order: order,
      message: "Payment verified and recorded successfully"
    )

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to record payment: #{e.message}"
    error_response("Failed to record payment: #{e.message}")
  end

  # Verify payment, record it, and mark order as paid
  # @param order [Order] The order to verify payment for
  # @param transaction_signature [String] The Solana transaction signature
  # @param sender_wallet [String] The wallet that sent the payment
  # @return [Hash] Result with success status and updated order
  def verify_and_confirm_payment(order:, transaction_signature:, sender_wallet:)
    # Verify and record the payment
    result = verify_and_record_payment(
      order: order,
      transaction_signature: transaction_signature,
      sender_wallet: sender_wallet
    )

    return result unless result[:success]

    # Mark order as paid
    order.pay!
    order.reload

    Rails.logger.info "✓ Order #{order.order_number} marked as paid"

    success_response(
      verified: true,
      paid: true,
      order: order,
      crypto_transaction: result[:crypto_transaction],
      transaction_details: result[:transaction_details],
      message: "Payment verified and order confirmed"
    )

  rescue AASM::InvalidTransition => e
    Rails.logger.error "Failed to update order status: #{e.message}"
    error_response("Failed to update order status: #{e.message}")
  end

  private

  def success_response(data)
    { success: true }.merge(data)
  end

  def error_response(message)
    {
      success: false,
      verified: false,
      error: message
    }
  end
end
