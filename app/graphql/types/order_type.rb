# frozen_string_literal: true

module Types
  class OrderType < Types::BaseObject
    field :id, ID, null: false
    field :order_number, String, null: false

    # Fiat currency amounts (for display/accounting)
    field :amount, Float, null: false, description: "Final amount in fiat currency (USD, MYR, etc.)"
    field :original_amount, Float, null: true, description: "Original amount before discount"
    field :currency, String, null: false, description: "Fiat currency (USD, MYR, etc.)"

    # Crypto amounts (actual payment)
    field :crypto_amount, Float, null: true, description: "Amount paid in cryptocurrency"
    field :crypto_amount_string, String, null: true, description: "Amount paid in cryptocurrency (formatted string)"
    field :crypto_currency, String, null: true, description: "Cryptocurrency used (SOL, USDT, etc.)"

    # Discount/VIP info
    field :discount_amount, Float, null: true, description: "Discount amount"
    field :discount_percent, Float, null: true, description: "Discount percentage"
    field :tier_at_purchase, String, null: true, description: "User's VIP tier at purchase"

    # Other fields
    field :status, String, null: false
    field :order_type, String, null: false
    field :user_data, GraphQL::Types::JSON, null: true
    field :metadata, GraphQL::Types::JSON, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :user, Types::UserType, null: false
    field :crypto_transaction, Types::CryptoTransactionType, null: true

    # Custom resolver to format crypto_amount properly without scientific notation
    def crypto_amount
      return nil unless object.crypto_amount
      # Convert to float but ensure proper formatting
      object.crypto_amount.to_f
    end

    def crypto_amount_string
      return nil unless object.crypto_amount
      # Return as properly formatted decimal string (no scientific notation)
      object.crypto_amount.to_s('F')
    end

    def user
      object.user
    end

    def crypto_transaction
      object.crypto_transaction
    end
  end
end
