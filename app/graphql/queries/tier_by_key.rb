module Queries
  class TierByKey < GraphQL::Schema::Resolver
    description "Get a specific tier by its key"

    argument :tier_key, String, required: true

    type Types::TierType, null: true

    def resolve(tier_key:)
      Tier.tier_by_key(tier_key)
    end
  end
end
