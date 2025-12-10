# frozen_string_literal: true

module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :wallet_address, String, null: false
    field :email, String, null: true
    field :email_verified, Boolean, null: false
    field :email_verified_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # VIP Tier fields
    field :tier, String, null: true, description: "Current VIP tier (elite, grandmaster, legend)"
    field :tier_name, String, null: true, description: "Display name for tier"
    field :discount_percent, Integer, null: false, description: "Current discount percentage"
    field :kohai_balance, Float, null: true, description: "Current $KOHAI token balance"
    field :tier_badge, String, null: true, description: "Badge display name"
    field :tier_style, String, null: true, description: "UI style (silver, gold, orange)"

    # Don't expose orders in user type to prevent deep queries
    # Use a separate query for user orders if needed

    def email_verified
      object.email_verified?
    end

    def tier
      object.tier
    end

    def tier_name
      object.tier&.titleize
    end

    def discount_percent
      TierService.check_tier_status(object)[:discount_percent]
    end

    def kohai_balance
      object.kohai_balance
    end

    def tier_badge
      TierService.check_tier_status(object)[:badge]
    end

    def tier_style
      TierService.check_tier_status(object)[:style]
    end
  end
end
