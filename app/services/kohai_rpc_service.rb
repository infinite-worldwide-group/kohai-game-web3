require 'net/http'
require 'uri'
require 'json'

module KohaiRpcService
  extend self

  # KOHAI Tier Thresholds - Now loaded from Tier database table
  # Falls back to ENV variables for backward compatibility during testing
  # Usage: Update Tier table or set KOHAI_ELITE_MIN, KOHAI_GRANDMASTER_MIN, KOHAI_LEGEND_MIN in .env

  # Class method to get current thresholds from database (with ENV fallback)
  def self.tier_thresholds
    # Try to load from database, fall back to ENV variables
    if defined?(Tier) && Tier.table_exists?
      elite_tier = Tier.active.order(:minimum_balance).first
      grandmaster_tier = Tier.active.order(:minimum_balance).second
      legend_tier = Tier.active.order(:minimum_balance).third

      {
        elite: elite_tier&.minimum_balance || ENV.fetch("KOHAI_ELITE_MIN", "5000").to_f,
        grandmaster: grandmaster_tier&.minimum_balance || ENV.fetch("KOHAI_GRANDMASTER_MIN", "50000").to_f,
        legend: legend_tier&.minimum_balance || ENV.fetch("KOHAI_LEGEND_MIN", "300000").to_f
      }
    else
      # Fallback to ENV variables if database not available
      {
        elite: ENV.fetch("KOHAI_ELITE_MIN", "5000").to_f,
        grandmaster: ENV.fetch("KOHAI_GRANDMASTER_MIN", "50000").to_f,
        legend: ENV.fetch("KOHAI_LEGEND_MIN", "300000").to_f
      }
    end
  end

  # Get the actual tier minimum thresholds
  def self.elite_min
    tier_thresholds[:elite]
  end

  def self.grandmaster_min
    tier_thresholds[:grandmaster]
  end

  def self.legend_min
    tier_thresholds[:legend]
  end

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
  # Uses Tier database table to determine thresholds and tier information
  # Falls back to ENV variables and hardcoded defaults if database unavailable
  # @param wallet_address [String] The wallet address to check
  # @return [Hash] Tier information including tier name, discount, badge, etc.
  def get_tier(wallet_address)
    balance = get_kohai_balance(wallet_address)

    # Try to get tier from database
    if defined?(Tier) && Tier.table_exists?
      tier = Tier.get_tier_for_balance(balance)
      return tier_response_from_db(tier, balance) unless tier.nil?
    end

    # Fallback to ENV variable-based thresholds
    tier_response_from_env(balance)
  end

  private

  def tier_response_from_db(tier, balance)
    if tier.is_a?(OpenStruct) && tier.tier_key == "none"
      {
        tier: :none,
        tier_name: nil,
        discount_percent: 0,
        referral_percent: 0,
        badge: nil,
        style: nil,
        balance: balance
      }
    else
      {
        tier: tier.tier_key.to_sym,
        tier_name: tier.name,
        discount_percent: tier.discount_percent.to_i,
        referral_percent: tier.discount_percent.to_i,
        badge: tier.badge_name,
        style: tier.badge_color,
        balance: balance
      }
    end
  end

  def tier_response_from_env(balance)
    elite_min = self.class.elite_min
    grandmaster_min = self.class.grandmaster_min
    legend_min = self.class.legend_min

    # Support both old tier keys (elite/grandmaster/legend) and new ones (elite/master/champion)
    case balance
    when legend_min..Float::INFINITY
      {
        tier: :champion,  # New tier_key
        tier_name: "Champion VVIP+",
        discount_percent: 3,
        referral_percent: 3,
        badge: "CHAMPION VVIP+",
        style: "orange",
        balance: balance
      }
    when grandmaster_min...legend_min
      {
        tier: :master,  # New tier_key
        tier_name: "Master VVIP",
        discount_percent: 2,
        referral_percent: 2,
        badge: "MASTER VVIP",
        style: "gold",
        balance: balance
      }
    when elite_min...grandmaster_min
      {
        tier: :elite,
        tier_name: "Elite VIP",
        discount_percent: 1,
        referral_percent: 1,
        badge: "ELITE VIP",
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
