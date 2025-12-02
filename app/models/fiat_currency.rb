# frozen_string_literal: true

class FiatCurrency < ApplicationRecord
  # Validations
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :symbol, presence: true
  validates :decimals, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :usd_rate, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :default, -> { where(is_default: true) }
  scope :stablecoins, -> { where(code: ['USDT', 'USDC', 'DAI', 'BUSD']) }
  scope :on_solana, -> { where(network: 'solana') }

  # Convert amount from smallest unit to human readable
  # Example: 1000000 USDT (6 decimals) -> 1.0 USDT
  def from_smallest_unit(amount)
    amount.to_f / (10 ** decimals)
  end

  # Convert human readable amount to smallest unit
  # Example: 1.0 USDT -> 1000000 (6 decimals)
  def to_smallest_unit(amount)
    (amount.to_f * (10 ** decimals)).to_i
  end

  # Check if this is a native token (SOL) or SPL token
  def native_token?
    token_mint.nil?
  end

  def spl_token?
    token_mint.present?
  end

  # Convert amount to USD
  def to_usd(amount)
    amount.to_f * usd_rate
  end

  # Format display
  def display_name
    "#{name} (#{symbol})"
  end
end
