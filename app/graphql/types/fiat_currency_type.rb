# frozen_string_literal: true

module Types
  class FiatCurrencyType < Types::BaseObject
    description "A fiat currency or stablecoin"

    field :id, ID, null: false
    field :code, String, null: false, description: "Currency code (e.g., USD, MYR, USDT)"
    field :name, String, null: false, description: "Full currency name"
    field :symbol, String, null: false, description: "Currency symbol (e.g., $, RM, ฿)"
    field :decimals, Integer, null: false, description: "Number of decimal places"
    field :usd_rate, Float, null: false, description: "Exchange rate to USD (1 unit of this currency = X USD)"
    field :network, String, null: true, description: "Blockchain network (e.g., solana) or null for fiat"
    field :token_mint, String, null: true, description: "Token mint address for crypto (null for fiat)"
    field :is_active, Boolean, null: false
    field :is_default, Boolean, null: false
    field :display_name, String, null: false, description: "Formatted display name"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Helper to convert amount from this currency to USD
    field :to_usd, Float, null: false do
      argument :amount, Float, required: true
    end

    def to_usd(amount:)
      object.to_usd(amount)
    end
  end
end
