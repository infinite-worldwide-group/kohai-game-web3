module Queries
  class Tiers < GraphQL::Schema::Resolver
    description "Get all active tiers"

    argument :sort_by, String, required: false, default_value: "order"
    argument :include_inactive, Boolean, required: false, default_value: false

    type [Types::TierType], null: false

    def resolve(sort_by:, include_inactive:)
      tiers = if include_inactive
                Tier.all
              else
                Tier.active
              end

      case sort_by
      when "order"
        tiers.by_order
      when "balance"
        tiers.by_balance_requirement
      when "discount"
        tiers.order(discount_percent: :desc)
      else
        tiers.by_order
      end
    end
  end
end
