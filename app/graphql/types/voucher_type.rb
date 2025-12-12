# frozen_string_literal: true

module Types
  class VoucherType < Types::BaseObject
    field :id, ID, null: false
    field :voucher_type, String, null: false
    field :discount_percent, Float, null: false
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: false
    field :used, Boolean, null: false
    field :used_at, GraphQL::Types::ISO8601DateTime, null: true
    field :active, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def active
      object.active?
    end
  end
end
