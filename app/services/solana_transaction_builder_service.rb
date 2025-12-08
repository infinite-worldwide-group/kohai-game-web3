# frozen_string_literal: true

require 'net/http'
require 'json'
require 'open3'

# Service to create and send Solana transactions with memos
# Useful for refunds, payouts, and testing
class SolanaTransactionBuilderService
  class TransactionFailed < StandardError; end
  class InsufficientBalance < StandardError; end

  # Send SOL with memo
  # @param to_address [String] Recipient wallet address
  # @param amount_sol [Float] Amount in SOL
  # @param memo [String] Memo text (e.g., order number)
  # @param keypair_path [String] Path to sender's keypair file
  # @return [Hash] Transaction result
  def self.send_sol_with_memo(to_address:, amount_sol:, memo:, keypair_path: nil)
    keypair_path ||= ENV.fetch('PLATFORM_KEYPAIR_PATH', './platform-keypair.json')
    rpc_url = ENV.fetch('SOLANA_RPC_URL', 'https://api.mainnet-beta.solana.com')

    Rails.logger.info "[SolanaTransactionBuilder] Sending #{amount_sol} SOL to #{to_address} with memo: #{memo}"

    # Use Solana CLI to send transaction
    cmd = [
      'solana', 'transfer',
      '--url', rpc_url,
      '--keypair', keypair_path,
      '--allow-unfunded-recipient',
      '--with-memo', memo,
      to_address,
      amount_sol.to_s
    ]

    stdout, stderr, status = Open3.capture3(*cmd)

    unless status.success?
      Rails.logger.error "[SolanaTransactionBuilder] Transaction failed: #{stderr}"
      raise TransactionFailed, stderr
    end

    # Extract signature from output
    signature = extract_signature_from_output(stdout)

    Rails.logger.info "[SolanaTransactionBuilder] Transaction sent! Signature: #{signature}"

    {
      signature: signature,
      to_address: to_address,
      amount: amount_sol,
      memo: memo,
      status: 'sent'
    }
  rescue StandardError => e
    Rails.logger.error "[SolanaTransactionBuilder] Error: #{e.message}"
    raise
  end

  # Build transaction data for frontend (without sending)
  # Returns the transaction structure that frontend can sign and send
  # @param from_address [String] Sender wallet address
  # @param to_address [String] Recipient wallet address
  # @param amount_sol [Float] Amount in SOL
  # @param memo [String] Memo text
  # @return [Hash] Transaction structure
  def self.build_transaction_data(from_address:, to_address:, amount_sol:, memo:)
    {
      instructions: [
        # Instruction 1: Transfer SOL
        {
          program: 'system',
          programId: '11111111111111111111111111111111',
          type: 'transfer',
          params: {
            fromPubkey: from_address,
            toPubkey: to_address,
            lamports: (amount_sol * 1_000_000_000).to_i
          }
        },
        # Instruction 2: Add memo
        {
          program: 'spl-memo',
          programId: 'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr',
          data: memo
        }
      ],
      feePayer: from_address,
      recentBlockhash: fetch_recent_blockhash
    }
  end

  # Create transaction using RPC (more advanced)
  # This builds and sends transaction using pure RPC calls
  # Note: Requires ed25519 signing capability
  def self.send_transaction_via_rpc(to_address:, amount_sol:, memo:, private_key:)
    rpc_url = ENV.fetch('SOLANA_RPC_URL', 'https://api.mainnet-beta.solana.com')

    # This is a placeholder - actual implementation requires:
    # 1. Building the transaction message
    # 2. Signing with ed25519 private key
    # 3. Serializing to wire format
    # 4. Sending via sendTransaction RPC method

    # For Ruby, it's easier to use the CLI or a library
    # See: https://github.com/vividmuse/solana_rpc_ruby

    raise NotImplementedError, 'RPC transaction signing not yet implemented. Use send_sol_with_memo instead.'
  end

  # Verify transaction was successful
  # @param signature [String] Transaction signature
  # @return [Hash] Transaction details
  def self.verify_transaction(signature)
    rpc_url = ENV.fetch('SOLANA_RPC_URL', 'https://api.mainnet-beta.solana.com')

    uri = URI(rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
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
    data = JSON.parse(response.body)

    if data['result']
      {
        signature: signature,
        status: data['result']['meta']['err'] ? 'failed' : 'confirmed',
        slot: data['result']['slot'],
        block_time: data['result']['blockTime'],
        memo: extract_memo_from_transaction(data['result'])
      }
    else
      { signature: signature, status: 'not_found' }
    end
  end

  # Check if wallet has sufficient balance
  # @param wallet_address [String] Wallet address to check
  # @param required_amount [Float] Required amount in SOL
  # @return [Boolean] True if sufficient balance
  def self.sufficient_balance?(wallet_address, required_amount)
    balance = get_balance(wallet_address)
    balance >= required_amount
  end

  # Get wallet balance
  # @param wallet_address [String] Wallet address
  # @return [Float] Balance in SOL
  def self.get_balance(wallet_address)
    rpc_url = ENV.fetch('SOLANA_RPC_URL', 'https://api.mainnet-beta.solana.com')

    uri = URI(rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = {
      jsonrpc: '2.0',
      id: 1,
      method: 'getBalance',
      params: [wallet_address]
    }.to_json

    response = http.request(request)
    data = JSON.parse(response.body)

    if data['result']
      data['result']['value'].to_f / 1_000_000_000
    else
      0.0
    end
  end

  private

  def self.extract_signature_from_output(output)
    # Parse signature from CLI output
    # Example: "Signature: 5j7s8K3w9DL2..."
    match = output.match(/Signature:\s+([A-Za-z0-9]+)/)
    match ? match[1] : nil
  end

  def self.fetch_recent_blockhash
    rpc_url = ENV.fetch('SOLANA_RPC_URL', 'https://api.mainnet-beta.solana.com')

    uri = URI(rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = {
      jsonrpc: '2.0',
      id: 1,
      method: 'getLatestBlockhash'
    }.to_json

    response = http.request(request)
    data = JSON.parse(response.body)

    data.dig('result', 'value', 'blockhash')
  end

  def self.extract_memo_from_transaction(transaction_data)
    instructions = transaction_data.dig('transaction', 'message', 'instructions') || []

    memo_instruction = instructions.find do |instruction|
      instruction['program'] == 'spl-memo'
    end

    memo_instruction&.dig('parsed')
  end
end
