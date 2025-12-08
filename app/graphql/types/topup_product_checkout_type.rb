# frozen_string_literal: true

module Types
  class TopupProductCheckoutType < Types::BaseObject
    description "Result of topup product checkout"

    field :order_number, String, null: false, description: "Unique order number"
    field :order_id, ID, null: false, description: "Order ID"
    field :payment_amount, Float, null: false, description: "Amount to pay in crypto"
    field :payment_currency, String, null: false, description: "Crypto currency to pay with (SOL, USDT, etc.)"
    field :wallet_to, String, null: false, description: "Platform wallet address to send payment to"
    field :price_usdt, Float, null: false, description: "Price in USDT"
    field :price_myr, Float, null: false, description: "Original price in MYR"
    field :status, String, null: false, description: "Order status"
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: false, description: "Payment expiration time"
  end
end
