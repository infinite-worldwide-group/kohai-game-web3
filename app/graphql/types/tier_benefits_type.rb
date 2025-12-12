module Types
  class TierBenefitsType < Types::BaseObject
    field :name, String
    field :tier_key, String
    field :minimum_balance, GraphQL::Types::BigInt
    field :discount_percent, Float
    field :badge, Types::BadgeInfoType
    field :description, String, null: true
  end
end
