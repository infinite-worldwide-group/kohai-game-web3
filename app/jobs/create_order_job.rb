class CreateOrderJob < ApplicationJob
  queue_as :default

  def perform(input_hash)
    input = input_hash.with_indifferent_access

    # Skip if order already exists
    return if Order.exists?(order_number: input[:order_number])

    # Create the order
    order = Order.create!(
      order_number: input[:order_number],
      user_id: input[:user_id],
      amount: input[:amount],
      currency: input[:currency],
      order_type: input[:order_type],
      payment_method: input[:payment_method],
      fiat_currency_id: input[:fiat_currency_id],
      topup_product_item_id: input[:topup_product_item_id],
      game_account_id: input[:game_account_id]
    )

    # Create crypto transaction if signature is present
    if input[:signature].present? && input[:payment_method] == "crypto"
      order.create_crypto_transaction!(
        transaction_signature: input[:signature],
        token: input[:token] || "USDC", # Default to USDC if not specified
        network: input[:network] || "solana",
        transaction_type: "payment",
        direction: "inbound",
        state: "pending"
      )
      
      # Verify the transaction on blockchain
      post_crypto(order)
    end
  end

  private

  def post_crypto(order)
    # Get the transaction signature from the crypto_transaction
    crypto_tx = order.crypto_transaction
    return handle_payment_failure(order, "Missing crypto transaction") if crypto_tx.blank?

    tx_signature = crypto_tx.transaction_signature
    return handle_payment_failure(order, "Missing transaction signature") if tx_signature.blank?

    # Get platform wallet address from ENV
    platform_wallet = ENV.fetch("SOLANA_PLATFORM_WALLET_ADDRESS")

    # Get user's wallet address
    user_wallet = order.user.wallet_address
    return handle_payment_failure(order, "User wallet address not found") if user_wallet.blank?

    # Retry logic for transaction indexing delay
    # Sometimes RPC nodes take a few seconds to index new transactions
    max_retries = 3
    retry_delay = 2 # seconds
    transaction = nil

    max_retries.times do |attempt|
      Rails.logger.info "Attempt #{attempt + 1}/#{max_retries}: Checking for transaction #{tx_signature}"

      # Check both platform wallet AND user wallet for the transaction
      # This helps handle indexing delays better
      platform_signatures = SolanaApi.get_signatures_for_address(platform_wallet, 100)
      user_signatures = SolanaApi.get_signatures_for_address(user_wallet, 100)

      # Find transaction in either wallet's history
      transaction = platform_signatures["result"]&.find do |tx|
        tx["signature"] == tx_signature && (tx["confirmationStatus"] == "finalized" || tx["confirmationStatus"] == "confirmed") && tx["err"].nil?
      end

      # If not found in platform wallet, check user wallet
      transaction ||= user_signatures["result"]&.find do |tx|
        tx["signature"] == tx_signature && (tx["confirmationStatus"] == "finalized" || tx["confirmationStatus"] == "confirmed") && tx["err"].nil?
      end

      if transaction
        Rails.logger.info "Found transaction on attempt #{attempt + 1}"

        # Verify the transaction details match expectations
        tx_details = SolanaApi.get_transaction(tx_signature)
        if tx_details && tx_details["result"]
          # Use SolanaTransactionService to parse transaction details
          details = SolanaTransactionService.parse_transaction_details(tx_details)
          
          tx_sender = details[:from_address]
          tx_receiver = details[:to_address]
          actual_amount = BigDecimal(details[:amount_lamports].to_s)
          
          if details[:is_spl_token]
            # Amount is already in UI format (e.g., 0.045 USDT)
            Rails.logger.info "SPL Token Transfer: #{actual_amount} (from blockchain)"
          else
            # Convert lamports to SOL
            actual_amount = actual_amount / BigDecimal('1000000000')
            Rails.logger.info "SOL Transfer: #{actual_amount} SOL (from blockchain)"
          end

          # Validate sender matches user's wallet
          unless tx_sender&.strip == user_wallet&.strip
            Rails.logger.error "Transaction sender #{tx_sender} does not match user wallet #{user_wallet}"
            return handle_payment_failure(order, "Transaction sender does not match your wallet address")
          end

          # Validate receiver matches platform wallet
          unless tx_receiver&.strip == platform_wallet&.strip
            Rails.logger.error "Transaction receiver #{tx_receiver} does not match platform wallet #{platform_wallet}"
            return handle_payment_failure(order, "Transaction was not sent to the platform wallet")
          end
            
            # UPDATE ORDER WITH ACTUAL AMOUNT FROM BLOCKCHAIN
          order.update!(crypto_amount: actual_amount)
          Rails.logger.info "Updated order crypto_amount to actual blockchain amount: #{actual_amount}"

          Rails.logger.info "Transaction verified: #{tx_sender} -> #{tx_receiver}, Amount: #{actual_amount}"
        end

        break
      else
        Rails.logger.warn "Transaction not found on attempt #{attempt + 1}/#{max_retries}"

        # Wait before retrying (but not on the last attempt)
        sleep(retry_delay) if attempt < max_retries - 1
      end
    end

    if transaction
      # Get the actual amount from the order (which was just updated with blockchain amount)
      actual_crypto_amount = order.reload.crypto_amount
      
      # Transaction found, verified, and confirmed
      crypto_tx.update!(
        state: "confirmed",
        amount: actual_crypto_amount,  # Update with actual blockchain amount
        confirmations: 1,
        block_timestamp: transaction["blockTime"] ? Time.at(transaction["blockTime"]) : nil,
        metadata: transaction.to_json
      )
      
      Rails.logger.info "CryptoTransaction updated with actual amount: #{actual_crypto_amount}"

      # Process the order (this will trigger the purchase_game_credit callback)
      order.process!
    elsif get_wallet["result"]&.any? { |tx| tx["signature"] == tx_signature }
      # Transaction found but not confirmed or has errors
      tx_data = get_wallet["result"].find { |tx| tx["signature"] == tx_signature }

      if tx_data["err"].present?
        crypto_tx.fail!
        handle_payment_failure(order, "Transaction failed: #{tx_data['err']}")
      else
        handle_payment_failure(order, "Transaction is still pending on blockchain")
      end
    else
      # Transaction not found in platform wallet history
      handle_payment_failure(order, "Transaction not found on blockchain")
    end
  rescue => e
    handle_payment_failure(order, "Error verifying transaction: #{e.message}")
  end

  def handle_payment_failure(order, message)
    order.update(error_message: message)
    order.fail!
  end
end
