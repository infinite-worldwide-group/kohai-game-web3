# frozen_string_literal: true

# Service to convert between fiat currencies and crypto
module CurrencyConversionService
  extend self

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
