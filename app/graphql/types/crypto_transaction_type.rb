# frozen_string_literal: true

module Types
  class CryptoTransactionType < Types::BaseObject
    field :id, ID, null: false
    field :transaction_signature, String, null: false
    field :wallet_from, String, null: true
    field :wallet_to, String, null: true
    field :amount, Float, null: true, description: "Transaction amount (may use scientific notation for small values)"
    field :amount_string, String, null: true, description: "Transaction amount as formatted decimal string"
    field :token, String, null: false
    field :network, String, null: false
    field :transaction_type, String, null: false
    field :direction, String, null: false
    field :state, String, null: false
    field :confirmations, Integer, null: true
    field :verified_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Custom resolver to format amount without scientific notation
    def amount_string
      return nil unless object.amount
      # Return as properly formatted decimal string
      BigDecimal(object.amount.to_s).to_s('F')
    end
  end
end
