# frozen_string_literal: true

# Seed fiat currencies (stablecoins and fiat money only, NOT crypto like SOL)

puts "Seeding fiat currencies..."

# USDT - Tether USD on Solana
FiatCurrency.find_or_create_by!(code: 'USDT') do |currency|
  currency.name = 'Tether USD'
  currency.symbol = 'USDT'
  currency.token_mint = 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB' # USDT mint on Solana mainnet
  currency.decimals = 6
  currency.network = 'solana'
  currency.usd_rate = 1.0 # Stablecoin pegged to USD
  currency.is_active = true
  currency.is_default = true
  currency.metadata = {
    type: 'stablecoin',
    issuer: 'Tether',
    website: 'https://tether.to'
  }
end

# USDC - USD Coin on Solana
FiatCurrency.find_or_create_by!(code: 'USDC') do |currency|
  currency.name = 'USD Coin'
  currency.symbol = 'USDC'
  currency.token_mint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v' # USDC mint on Solana mainnet
  currency.decimals = 6
  currency.network = 'solana'
  currency.usd_rate = 1.0 # Stablecoin pegged to USD
  currency.is_active = true
  currency.is_default = false
  currency.metadata = {
    type: 'stablecoin',
    issuer: 'Circle',
    website: 'https://www.circle.com/en/usdc'
  }
end

# USD - Traditional fiat (for reference/display only)
FiatCurrency.find_or_create_by!(code: 'USD') do |currency|
  currency.name = 'US Dollar'
  currency.symbol = 'USD'
  currency.token_mint = nil # Traditional fiat, no blockchain token
  currency.decimals = 2
  currency.network = nil
  currency.usd_rate = 1.0 # Base currency
  currency.is_active = true
  currency.is_default = false
  currency.metadata = {
    type: 'fiat',
    country: 'United States'
  }
end

# MYR - Malaysian Ringgit
FiatCurrency.find_or_create_by!(code: 'MYR') do |currency|
  currency.name = 'Malaysian Ringgit'
  currency.symbol = 'RM'
  currency.token_mint = nil
  currency.decimals = 2
  currency.network = nil
  currency.usd_rate = 0.22 # Initial rate, will be updated by UpdateCurrencyRatesJob
  currency.is_active = true
  currency.is_default = false
  currency.metadata = {
    type: 'fiat',
    country: 'Malaysia'
  }
end

# SGD - Singapore Dollar
FiatCurrency.find_or_create_by!(code: 'SGD') do |currency|
  currency.name = 'Singapore Dollar'
  currency.symbol = 'S$'
  currency.token_mint = nil
  currency.decimals = 2
  currency.network = nil
  currency.usd_rate = 0.74 # Initial rate, will be updated by UpdateCurrencyRatesJob
  currency.is_active = true
  currency.is_default = false
  currency.metadata = {
    type: 'fiat',
    country: 'Singapore'
  }
end

# THB - Thai Baht
FiatCurrency.find_or_create_by!(code: 'THB') do |currency|
  currency.name = 'Thai Baht'
  currency.symbol = '฿'
  currency.token_mint = nil
  currency.decimals = 2
  currency.network = nil
  currency.usd_rate = 0.029 # Initial rate, will be updated by UpdateCurrencyRatesJob
  currency.is_active = true
  currency.is_default = false
  currency.metadata = {
    type: 'fiat',
    country: 'Thailand'
  }
end

# IDR - Indonesian Rupiah
FiatCurrency.find_or_create_by!(code: 'IDR') do |currency|
  currency.name = 'Indonesian Rupiah'
  currency.symbol = 'Rp'
  currency.token_mint = nil
  currency.decimals = 0
  currency.network = nil
  currency.usd_rate = 0.000064 # Initial rate, will be updated by UpdateCurrencyRatesJob
  currency.is_active = true
  currency.is_default = false
  currency.metadata = {
    type: 'fiat',
    country: 'Indonesia'
  }
end

# PHP - Philippine Peso
FiatCurrency.find_or_create_by!(code: 'PHP') do |currency|
  currency.name = 'Philippine Peso'
  currency.symbol = '₱'
  currency.token_mint = nil
  currency.decimals = 2
  currency.network = nil
  currency.usd_rate = 0.018 # Initial rate, will be updated by UpdateCurrencyRatesJob
  currency.is_active = true
  currency.is_default = false
  currency.metadata = {
    type: 'fiat',
    country: 'Philippines'
  }
end

# VND - Vietnamese Dong
FiatCurrency.find_or_create_by!(code: 'VND') do |currency|
  currency.name = 'Vietnamese Dong'
  currency.symbol = '₫'
  currency.token_mint = nil
  currency.decimals = 0
  currency.network = nil
  currency.usd_rate = 0.000041 # Initial rate, will be updated by UpdateCurrencyRatesJob
  currency.is_active = true
  currency.is_default = false
  currency.metadata = {
    type: 'fiat',
    country: 'Vietnam'
  }
end

puts "✓ Created #{FiatCurrency.count} fiat currencies"
FiatCurrency.all.each do |currency|
  puts "  - #{currency.display_name} (#{currency.code}): $#{currency.usd_rate} USD"
end
