# frozen_string_literal: true

module Types
  class TierStatusType < Types::BaseObject
    description "User's VIP tier status information"

    field :tier, String, null: true, description: "Tier identifier (elite, grandmaster, legend)"
    field :tier_name, String, null: true, description: "Display name for tier"
    field :discount_percent, Integer, null: false, description: "Discount percentage for orders"
    field :referral_percent, Integer, null: false, description: "Referral commission percentage"
    field :badge, String, null: true, description: "Badge display text"
    field :style, String, null: true, description: "UI style (silver, gold, orange)"
    field :balance, Float, null: false, description: "Current $KOHAI token balance"
    field :cached, Boolean, null: false, description: "Whether this data is from cache"
    field :last_checked_at, GraphQL::Types::ISO8601DateTime, null: true, description: "When tier was last checked"
  end
end
