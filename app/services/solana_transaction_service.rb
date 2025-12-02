# frozen_string_literal: true

require 'net/http'
require 'json'

# Service to verify Solana transactions on-chain
# Checks transaction status directly from Solana RPC
class SolanaTransactionService
  class TransactionNotFound < StandardError; end
  class InsufficientConfirmations < StandardError; end
  class InvalidTransaction < StandardError; end

  REQUIRED_CONFIRMATIONS = 1
  LAMPORTS_PER_SOL = 1_000_000_000

  # Verify a transaction on Solana blockchain using wallet history
  # This is more reliable for recent transactions than getTransaction
  # @param signature [String] Transaction signature
  # @param expected_amount [Decimal] Expected amount in SOL
  # @param expected_receiver [String] Expected receiver wallet address
  # @param expected_sender [String] Expected sender wallet address
  # @return [Hash] Transaction details
  def self.verify_transaction(signature:, expected_amount:, expected_receiver:, expected_sender: nil)
    Rails.logger.info "Verifying transaction: #{signature}"
    Rails.logger.info "Expected receiver: #{expected_receiver}"
    Rails.logger.info "Expected sender: #{expected_sender}"

    # Retry logic for signature indexing delay
    # Sometimes RPC nodes take a few seconds to index new transactions
    max_retries = 3
    retry_delay = 2 # seconds

    tx_signature = nil
    signatures_response = nil

    max_retries.times do |attempt|
      Rails.logger.info "Attempt #{attempt + 1}/#{max_retries}: Checking for transaction in wallet history"

      # Check both receiver's wallet AND sender's wallet (if provided)
      # This handles RPC indexing delays better
      receiver_signatures = fetch_signatures_for_address(expected_receiver, limit: 100)

      unless receiver_signatures && receiver_signatures['result']
        error_msg = receiver_signatures&.dig('error', 'message') || 'Unknown error'
        Rails.logger.error "Failed to fetch transaction history: #{error_msg}"
        raise TransactionNotFound, "Unable to fetch transaction history for wallet: #{error_msg}"
      end

      # Find transaction in receiver's wallet
      tx_signature = receiver_signatures['result'].find { |tx| tx['signature'] == signature }

      # If not found in receiver's wallet and sender is provided, check sender's wallet
      if tx_signature.nil? && expected_sender.present?
        Rails.logger.info "Transaction not in receiver's history, checking sender's wallet..."
        sender_signatures = fetch_signatures_for_address(expected_sender, limit: 100)

        if sender_signatures && sender_signatures['result']
          tx_signature = sender_signatures['result'].find { |tx| tx['signature'] == signature }

          if tx_signature
            Rails.logger.info "Found transaction in sender's wallet history"
          end
        end
      end

      if tx_signature
        Rails.logger.info "Found transaction in history on attempt #{attempt + 1}"
        break
      else
        Rails.logger.warn "Transaction not found in wallet history (attempt #{attempt + 1}/#{max_retries})"

        # On last attempt, raise error
        if attempt == max_retries - 1
          Rails.logger.error "Transaction #{signature} not found after #{max_retries} attempts"
          first_sigs = receiver_signatures['result'].first(5).map { |tx| tx['signature'] }
          Rails.logger.error "Recent signatures in receiver wallet: #{first_sigs.join(', ')}"
          raise TransactionNotFound, "Transaction #{signature} not found in wallet history after #{max_retries} attempts"
        end

        # Wait before retrying
        sleep(retry_delay)
      end
    end

    unless tx_signature
      raise TransactionNotFound, "Transaction #{signature} not found in wallet history"
    end

    # Check if transaction is finalized
    unless tx_signature['confirmationStatus'] == 'finalized' || tx_signature['confirmationStatus'] == 'confirmed'
      raise InsufficientConfirmations, "Transaction is #{tx_signature['confirmationStatus']}, waiting for finalization"
    end

    # Check if transaction has errors
    if tx_signature['err'].present?
      raise InvalidTransaction, "Transaction failed on blockchain: #{tx_signature['err']}"
    end

    # Now try to get full transaction details for amount validation
    transaction_info = fetch_transaction(signature)

    if transaction_info && transaction_info['result']
      # Parse full transaction details if available
      details = parse_transaction_details(transaction_info)

      # Validate sender (if provided)
      if expected_sender.present? && details[:from_address] != expected_sender
        raise InvalidTransaction, "Transaction sender #{details[:from_address]} does not match expected #{expected_sender}"
      end

      # Validate receiver
      if details[:to_address] != expected_receiver
        raise InvalidTransaction, "Transaction receiver #{details[:to_address]} does not match expected #{expected_receiver}"
      end

      # Validate amount - allow if paid amount is >= expected (user can overpay)
      amount_sol = details[:amount_lamports].to_f / LAMPORTS_PER_SOL
      expected_sol = expected_amount.to_f
      tolerance = 0.01 # Allow 1% variance for price fluctuations

      # Check if user paid enough (allow overpayment, but not underpayment beyond tolerance)
      if amount_sol < (expected_sol - tolerance)
        raise InvalidTransaction, "Transaction amount #{amount_sol} SOL is less than expected #{expected_sol} SOL"
      end

      Rails.logger.info "Amount validation passed: paid #{amount_sol} SOL, expected #{expected_sol} SOL"

      {
        signature: signature,
        from_address: details[:from_address],
        to_address: details[:to_address],
        amount: amount_sol,
        amount_lamports: details[:amount_lamports],
        block_timestamp: details[:block_timestamp],
        block_number: details[:block_number],
        confirmations: 1,
        fee_lamports: details[:fee],
        status: 'confirmed'
      }
    else
      # If full transaction details aren't available yet, return basic info
      # This can happen with very recent transactions
      Rails.logger.warn "Transaction #{signature} found in signatures but full details not available yet"

      {
        signature: signature,
        from_address: expected_sender,
        to_address: expected_receiver,
        amount: expected_amount.to_f,
        amount_lamports: (expected_amount.to_f * LAMPORTS_PER_SOL).to_i,
        block_timestamp: tx_signature['blockTime'],
        block_number: tx_signature['slot'],
        confirmations: 1,
        fee_lamports: 5000, # Estimate
        status: 'confirmed'
      }
    end
  end

  # Fetch signatures for a wallet address
  def self.fetch_signatures_for_address(wallet_address, limit: 100)
    rpc_url = ENV.fetch('SOLANA_RPC_URL', 'https://api.mainnet-beta.solana.com')

    uri = URI(rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)
    request['Content-Type'] = 'application/json'

    request.body = {
      jsonrpc: '2.0',
      id: 1,
      method: 'getSignaturesForAddress',
      params: [
        wallet_address,
        { limit: limit }
      ]
    }.to_json

    response = http.request(request)

    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      Rails.logger.error "Solana RPC error: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching signatures for address: #{e.message}"
    nil
  end

  # Fetch transaction from Solana RPC
  def self.fetch_transaction(signature)
    rpc_url = ENV.fetch('SOLANA_RPC_URL', 'https://api.mainnet-beta.solana.com')

    uri = URI(rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)
    request['Content-Type'] = 'application/json'

    # RPC request to get transaction
    request.body = {
      jsonrpc: '2.0',
      id: 1,
      method: 'getTransaction',
      params: [
        signature,
        {
          encoding: 'jsonParsed',
          maxSupportedTransactionVersion: 0
        }
      ]
    }.to_json

    response = http.request(request)

    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      Rails.logger.error "Solana RPC error: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching Solana transaction: #{e.message}"
    nil
  end

  # Parse transaction details from RPC response
  def self.parse_transaction_details(transaction_info)
    result = transaction_info['result']
    meta = result['meta']
    transaction = result['transaction']

    # Extract transfer details from parsed instructions
    transfer_instruction = find_transfer_instruction(transaction)

    {
      from_address: transfer_instruction&.dig('parsed', 'info', 'source'),
      to_address: transfer_instruction&.dig('parsed', 'info', 'destination'),
      amount_lamports: transfer_instruction&.dig('parsed', 'info', 'lamports') || 0,
      block_timestamp: result['blockTime'],
      block_number: result['slot'],
      fee: meta['fee'],
      error: meta['err']
    }
  end

  # Find SOL transfer instruction in transaction
  def self.find_transfer_instruction(transaction)
    instructions = transaction.dig('message', 'instructions') || []

    instructions.find do |instruction|
      instruction.dig('parsed', 'type') == 'transfer' &&
        instruction['program'] == 'system'
    end
  end

  # Check transaction status (for polling)
  def self.check_status(signature)
    transaction_info = fetch_transaction(signature)

    return { status: 'not_found', confirmations: 0 } unless transaction_info

    result = transaction_info['result']
    return { status: 'not_found', confirmations: 0 } unless result

    # If transaction exists in getTransaction response, it's finalized
    error = result.dig('meta', 'err')

    status = if error
               'failed'
             else
               'confirmed'
             end

    { status: status, confirmations: 1 }
  end

  # Extract memo from transaction (for QR code payment tracking)
  def self.extract_memo(transaction_info)
    return nil unless transaction_info

    result = transaction_info['result']
    return nil unless result

    instructions = result.dig('transaction', 'message', 'instructions') || []

    # Look for memo instruction
    memo_instruction = instructions.find do |instruction|
      instruction['program'] == 'spl-memo' || instruction['programId'] == 'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr'
    end

    return nil unless memo_instruction

    # Decode memo data
    if memo_instruction['parsed']
      memo_instruction['parsed']
    elsif memo_instruction['data']
      # Base64 decode if not parsed
      Base64.decode64(memo_instruction['data'])
    end
  rescue StandardError => e
    Rails.logger.error "Error extracting memo: #{e.message}"
    nil
  end

  # Fetch recent incoming transactions for a wallet (for monitoring)
  # @param wallet_address [String] Wallet address to check
  # @param limit [Integer] Number of recent transactions to fetch
  # @return [Array<Hash>] Array of transaction details
  def self.fetch_incoming_transactions(wallet_address:, limit: 10)
    rpc_url = ENV.fetch('SOLANA_RPC_URL', 'https://api.mainnet-beta.solana.com')

    uri = URI(rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)
    request['Content-Type'] = 'application/json'

    # Get signatures for address
    request.body = {
      jsonrpc: '2.0',
      id: 1,
      method: 'getSignaturesForAddress',
      params: [
        wallet_address,
        {
          limit: limit
        }
      ]
    }.to_json

    response = http.request(request)
    return [] unless response.code.to_i == 200

    data = JSON.parse(response.body)
    signatures = data.dig('result') || []

    # Fetch details for each transaction
    transactions = []
    signatures.each do |sig_info|
      signature = sig_info['signature']
      next if sig_info['err'] # Skip failed transactions

      transaction_info = fetch_transaction(signature)
      next unless transaction_info

      details = parse_transaction_details(transaction_info)
      memo = extract_memo(transaction_info)

      # Only include incoming transactions (where wallet is receiver)
      if details[:to_address] == wallet_address
        transactions << {
          signature: signature,
          from_address: details[:from_address],
          to_address: details[:to_address],
          amount: details[:amount_lamports].to_f / LAMPORTS_PER_SOL,
          amount_lamports: details[:amount_lamports],
          memo: memo,
          block_timestamp: details[:block_timestamp],
          confirmations: 1 # Transaction exists in response, so it's finalized
        }
      end
    end

    transactions
  rescue StandardError => e
    Rails.logger.error "Error fetching incoming transactions: #{e.message}"
    []
  end
end
