# frozen_string_literal: true

# Job to update fiat currency exchange rates from external API
# Runs periodically to keep rates current
class UpdateCurrencyRatesJob < ApplicationJob
  queue_as :default

  # Free tier API - no auth required, 1500 requests/month
  EXCHANGE_RATE_API_URL = 'https://api.exchangerate-api.com/v4/latest/USD'

  def perform(*args)
    Rails.logger.info "UpdateCurrencyRatesJob: Fetching latest exchange rates..."

    rates = fetch_exchange_rates
    return unless rates.present?

    updated_count = 0
    errors = []

    FiatCurrency.find_each do |currency|
      next if currency.code == 'USD' # USD is base currency (rate = 1.0)

      # For stablecoins, keep rate at 1.0
      if ['USDT', 'USDC', 'DAI', 'BUSD'].include?(currency.code)
        if currency.usd_rate != 1.0
          currency.update(usd_rate: 1.0)
          updated_count += 1
          Rails.logger.info "Updated #{currency.code} to 1.0 (stablecoin)"
        end
        next
      end

      # For fiat currencies, get rate from API
      # API returns rates as "1 USD = X currency", we need "1 currency = X USD"
      api_rate = rates[currency.code]
      
      if api_rate.present?
        # Convert to "how many USD per 1 unit of this currency"
        new_usd_rate = (1.0 / api_rate.to_f).round(8)
        
        if currency.usd_rate != new_usd_rate
          old_rate = currency.usd_rate
          currency.update(usd_rate: new_usd_rate)
          updated_count += 1
          Rails.logger.info "Updated #{currency.code}: #{old_rate} -> #{new_usd_rate} USD"
        end
      else
        errors << "No rate found for #{currency.code}"
      end
    end

    Rails.logger.info "UpdateCurrencyRatesJob: Updated #{updated_count} currencies"
    Rails.logger.warn "UpdateCurrencyRatesJob: Errors: #{errors.join(', ')}" if errors.any?

    # Update cache timestamp
    Rails.cache.write('currency_rates_last_updated', Time.current, expires_in: 24.hours)
  end

  private

  def fetch_exchange_rates
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI(EXCHANGE_RATE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 10
    http.read_timeout = 15

    response = http.get(uri.request_uri)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Exchange rate API returned #{response.code}: #{response.body}"
      return fallback_to_backup_api
    end

    data = JSON.parse(response.body)
    rates = data['rates']

    unless rates.present?
      Rails.logger.error "No rates in API response: #{response.body}"
      return fallback_to_backup_api
    end

    Rails.logger.info "Fetched #{rates.keys.count} exchange rates from API"
    rates
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse exchange rate API response: #{e.message}"
    fallback_to_backup_api
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "Timeout fetching exchange rates: #{e.message}"
    fallback_to_backup_api
  rescue StandardError => e
    Rails.logger.error "Error fetching exchange rates: #{e.class} - #{e.message}"
    fallback_to_backup_api
  end

  # Backup API if primary fails (CoinGecko or frankfurter.app)
  def fallback_to_backup_api
    Rails.logger.info "Trying backup API (Frankfurter)..."

    uri = URI('https://api.frankfurter.app/latest?from=USD')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 10
    http.read_timeout = 15

    response = http.get(uri.request_uri)
    data = JSON.parse(response.body)
    
    rates = data['rates']
    Rails.logger.info "Fetched #{rates.keys.count} rates from backup API"
    rates
  rescue => e
    Rails.logger.error "Backup API also failed: #{e.message}"
    nil
  end
end
