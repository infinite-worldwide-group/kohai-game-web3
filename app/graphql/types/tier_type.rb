module Types
  class TierType < Types::BaseObject
    field :id, ID
    field :name, String
    field :tier_key, String
    field :minimum_balance, GraphQL::Types::BigInt
    field :discount_percent, Float
    field :badge_name, String, null: true
    field :badge_color, String, null: true
    field :description, String, null: true
    field :display_order, Integer
    field :is_active, Boolean
    field :display_name, String
    field :tier_benefits, Types::TierBenefitsType
    field :created_at, GraphQL::Types::ISO8601DateTime
    field :updated_at, GraphQL::Types::ISO8601DateTime
  end
end
