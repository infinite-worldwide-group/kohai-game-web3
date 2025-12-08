# frozen_string_literal: true

# Service to convert between fiat currencies and crypto
# Uses real-time rates from fiat_currencies table (updated by UpdateCurrencyRatesJob)
module CurrencyConversionService
  extend self

  # Fallback rates if database is unavailable (should rarely be used)
  FALLBACK_RATES = {
    'USD' => 1.0,
    'USDT' => 1.0,
    'USDC' => 1.0,
    'MYR' => 4.50,
    'SGD' => 1.35,
    'THB' => 35.0,
    'IDR' => 15700.0,
    'PHP' => 56.0,
    'VND' => 24500.0
  }.freeze

  # Get live exchange rate for a currency from database
  # @param currency_code [String] Currency code (e.g., 'MYR', 'USDT')
  # @return [Float] Rate in USD (how much 1 unit = X USD)
  def get_rate(currency_code)
    code = currency_code.to_s.upcase
    return 1.0 if code == 'USD'

    # Try cache first (5 minute cache to reduce DB queries)
    cache_key = "currency_rate_#{code}"
    cached = Rails.cache.read(cache_key)
    return cached if cached.present?

    # Fetch from database
    currency = FiatCurrency.find_by(code: code, is_active: true)
    
    if currency.present?
      rate = currency.usd_rate
      Rails.cache.write(cache_key, rate, expires_in: 5.minutes)
      return rate
    end

    # Fallback to hardcoded rate if not in DB
    Rails.logger.warn "Currency #{code} not found in database, using fallback rate"
    FALLBACK_RATES[code] || raise(ArgumentError, "Unsupported currency: #{code}")
  end

  # List of supported currencies from database
  def supported_currencies_list
    FiatCurrency.active.pluck(:code)
  end

  # Convert from one currency to another using live rates
  # @param amount [Float] Amount in source currency
  # @param from_currency [String] Source currency code
  # @param to_currency [String] Target currency code
  # @return [Float] Amount in target currency
  def convert(amount, from_currency:, to_currency:)
    return amount if from_currency.upcase == to_currency.upcase

    from_rate = get_rate(from_currency)
    to_rate = get_rate(to_currency)

    # Convert: amount in source -> USD -> target
    # from_rate = how much USD per 1 source currency
    # to_rate = how much USD per 1 target currency
    amount_in_usd = amount * from_rate
    amount_in_target = amount_in_usd / to_rate

    amount_in_target.round(8)
  end

  # Get all supported currencies with their current rates
  # @return [Array<Hash>] Currency info with live rates
  def supported_currencies
    FiatCurrency.active.map do |currency|
      {
        code: currency.code,
        name: currency.name,
        symbol: currency.symbol,
        rate: currency.usd_rate,
        decimals: currency.decimals,
        network: currency.network,
        last_updated: Rails.cache.read('currency_rates_last_updated')
      }
    end
  rescue => e
    Rails.logger.error "Failed to fetch currencies from DB: #{e.message}"
    # Fallback to static list if DB fails
    FALLBACK_RATES.map do |code, rate|
      {
        code: code,
        rate: rate,
        symbol: currency_symbol(code)
      }
    end
  end

  # Get currency symbol
  # @param currency_code [String] Currency code
  # @return [String] Currency symbol
  def currency_symbol(currency_code)
    case currency_code.upcase
    when 'USD', 'USDT', 'USDC' then '$'
    when 'MYR' then 'RM'
    when 'SGD' then 'S$'
    when 'THB' then '฿'
    when 'IDR' then 'Rp'
    when 'PHP' then '₱'
    when 'VND' then '₫'
    else currency_code
    end
  end

  # Legacy methods for backward compatibility
  def myr_to_usdt(myr_amount)
    convert(myr_amount, from_currency: 'MYR', to_currency: 'USDT')
  end

  def usdt_to_myr(usdt_amount)
    convert(usdt_amount, from_currency: 'USDT', to_currency: 'MYR')
  end

  # Convert USD to SOL
  # @param usd_amount [Float] Amount in USD
  # @return [Float] Amount in SOL
  def usd_to_sol(usd_amount)
    sol_price_usd = get_sol_price_usd
    (usd_amount / sol_price_usd).round(9)
  end

  # Convert SOL to USD
  # @param sol_amount [Float] Amount in SOL
  # @return [Float] Amount in USD
  def sol_to_usd(sol_amount)
    sol_price_usd = get_sol_price_usd
    (sol_amount * sol_price_usd).round(2)
  end

  # Get current SOL price in USD
  # @return [Float] SOL price in USD
  def get_sol_price_usd
    # Try to get from cache first (5 minute cache)
    cached_price = Rails.cache.read('sol_price_usd')
    return cached_price if cached_price.present?

    # Fetch from API (CoinGecko free tier)
    price = fetch_sol_price_from_api

    # Cache for 5 minutes
    Rails.cache.write('sol_price_usd', price, expires_in: 5.minutes)

    price
  rescue => e
    Rails.logger.error "Failed to fetch SOL price: #{e.message}"
    # Fallback to hardcoded price if API fails
    150.0 # ~$150 USD per SOL (update this periodically)
  end

  private

  def fetch_sol_price_from_api
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI('https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd')

    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    data.dig('solana', 'usd')&.to_f || 150.0
  rescue => e
    Rails.logger.warn "CoinGecko API failed: #{e.message}"
    150.0
  end
end
