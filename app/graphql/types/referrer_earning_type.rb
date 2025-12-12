# frozen_string_literal: true

module Types
  class ReferrerEarningType < Types::BaseObject
    field :id, ID, null: false
    field :order_amount, Float, null: false
    field :commission_percent, Float, null: false
    field :commission_amount, Float, null: false
    field :currency, String, null: false
    field :status, String, null: false
    field :claimed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
