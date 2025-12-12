module Mutations
  class CreateTier < Mutations::BaseMutation
    description "Create a new tier"

    argument :name, String, required: true
    argument :tier_key, String, required: true
    argument :minimum_balance, GraphQL::Types::BigInt, required: true
    argument :discount_percent, Float, required: true
    argument :badge_name, String, required: false
    argument :badge_color, String, required: false
    argument :description, String, required: false
    argument :display_order, Integer, required: false, default_value: 0

    field :tier, Types::TierType
    field :errors, [String]

    def resolve(name:, tier_key:, minimum_balance:, discount_percent:, badge_name: nil, badge_color: nil, description: nil, display_order: 0)
      tier = Tier.new(
        name: name,
        tier_key: tier_key,
        minimum_balance: minimum_balance,
        discount_percent: discount_percent,
        badge_name: badge_name,
        badge_color: badge_color,
        description: description,
        display_order: display_order
      )

      if tier.save
        { tier: tier, errors: [] }
      else
        { tier: nil, errors: tier.errors.full_messages }
      end
    end
  end
end
