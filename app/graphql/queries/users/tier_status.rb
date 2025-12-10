# frozen_string_literal: true

module Queries
  module Users
    class TierStatus < Queries::BaseQuery
      description "Get current user's VIP tier status with optional real-time blockchain check"

      argument :force_refresh, Boolean, required: false, default_value: false

      type Types::TierStatusType, null: false

      def resolve(force_refresh: false)
        require_authentication!

        tier_info = TierService.check_tier_status(current_user, force_refresh: force_refresh)

        {
          tier: tier_info[:tier],
          tier_name: tier_info[:tier_name],
          discount_percent: tier_info[:discount_percent],
          referral_percent: tier_info[:referral_percent],
          badge: tier_info[:badge],
          style: tier_info[:style],
          balance: tier_info[:balance],
          cached: !force_refresh,
          last_checked_at: current_user.tier_checked_at
        }
      end
    end
  end
end
