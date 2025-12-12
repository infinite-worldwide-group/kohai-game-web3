module Mutations
  class UpdateTier < Mutations::BaseMutation
    description "Update an existing tier"

    argument :id, ID, required: true
    argument :name, String, required: false
    argument :minimum_balance, GraphQL::Types::BigInt, required: false
    argument :discount_percent, Float, required: false
    argument :badge_name, String, required: false
    argument :badge_color, String, required: false
    argument :description, String, required: false
    argument :display_order, Integer, required: false
    argument :is_active, Boolean, required: false

    field :tier, Types::TierType
    field :errors, [String]

    def resolve(id:, **attributes)
      tier = Tier.find_by(id: id)
      return { tier: nil, errors: ["Tier not found"] } unless tier

      if tier.update(attributes.compact)
        { tier: tier, errors: [] }
      else
        { tier: nil, errors: tier.errors.full_messages }
      end
    end
  end
end
