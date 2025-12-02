# frozen_string_literal: true

module Types
  class TransactionStatusType < Types::BaseObject
    field :signature, String, null: false
    field :status, String, null: false
    field :confirmations, Integer, null: false
    field :error, String, null: true
  end
end
