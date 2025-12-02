require 'net/http'
require 'uri'
require 'json'

module KohaiRpcService
  extend self

  # Get token accounts owned by a specific wallet address for a particular token mint
  # @param owner_address [String] The wallet address that owns the token accounts
  # @param mint_address [String] The token mint address to filter by
  # @return [Hash] JSON-RPC response containing token account information
  def get_token_accounts_by_owner(owner_address, mint_address)
    body = {
      jsonrpc: "2.0",
      id: 1,
      method: "getTokenAccountsByOwner",
      params: [
        owner_address,
        { mint: mint_address },
        { encoding: "jsonParsed" }
      ]
    }

    post(rpc_url, body)
  end

  # Get $KOHAI token balance for a wallet address
  # @param wallet_address [String] The wallet address to check
  # @return [Float] The token balance (uiAmount)
  def get_kohai_balance(wallet_address)
    kohai_mint = ENV.fetch("KOHAI_TOKEN_MINT")

    response = get_token_accounts_by_owner(wallet_address, kohai_mint)

    # Extract balance from response
    if response["result"] && response["result"]["value"].present?
      token_accounts = response["result"]["value"]

      # Sum up all token account balances (in case there are multiple accounts)
      total_balance = token_accounts.sum do |account|
        account.dig("account", "data", "parsed", "info", "tokenAmount", "uiAmount")&.to_f || 0.0
      end

      total_balance
    else
      0.0
    end
  rescue => e
    Rails.logger.error "Failed to fetch KOHAI balance for #{wallet_address}: #{e.message}"
    0.0
  end

  # Determine tier based on $KOHAI holdings
  # @param wallet_address [String] The wallet address to check
  # @return [Hash] Tier information { tier: :elite/:grandmaster/:legend, discount_percent: 1/2/3, badge: "Elite"/etc, style: "silver"/"gold"/"orange" }
  def get_tier(wallet_address)
    balance = get_kohai_balance(wallet_address)

    case balance
    when 3_000_000..Float::INFINITY
      {
        tier: :legend,
        tier_name: "Legend",
        discount_percent: 3,
        referral_percent: 3,
        badge: "Legend",
        style: "orange", # glowing orange name
        balance: balance
      }
    when 500_000...3_000_000
      {
        tier: :grandmaster,
        tier_name: "Grandmaster",
        discount_percent: 2,
        referral_percent: 2,
        badge: "Grandmaster",
        style: "gold",
        balance: balance
      }
    when 50_000...500_000
      {
        tier: :elite,
        tier_name: "Elite",
        discount_percent: 1,
        referral_percent: 1,
        badge: "Elite",
        style: "silver",
        balance: balance
      }
    else
      {
        tier: :none,
        tier_name: nil,
        discount_percent: 0,
        referral_percent: 0,
        badge: nil,
        style: nil,
        balance: balance
      }
    end
  end

  private

  def rpc_url
    # Using Helius RPC endpoint
    api_key = ENV.fetch("HELIUS_API_KEY", "4ce431ac-5a15-4727-b1d3-63fc3ccb4c91")
    "https://mainnet.helius-rpc.com/?api-key=#{api_key}"
  end

  def post(url, body)
    uri = URI(url)

    puts "POST request to: #{url} with body: #{body}"

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = JSON.dump(body)

    response = https.request(request)

    case response.code
    when '401'
      raise "Unauthorized: #{response.code} - #{response.message}"
    when '404'
      raise "Not Found: #{response.code} - #{response.message}"
    when '500'
      raise "Internal Server Error: #{response.code} - #{response.message}"
    else
      JSON.parse(response.body)
    end
  end
end
