# frozen_string_literal: true

module Types
  class ReferralCodeType < Types::BaseObject
    field :id, ID, null: false
    field :code, String, null: false
    field :total_uses, Integer, null: false
    field :total_earnings, Float, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
