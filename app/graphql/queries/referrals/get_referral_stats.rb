# frozen_string_literal: true

module Queries
  module Referrals
    class GetReferralStats < Queries::BaseQuery
      type Types::ReferralStatsType, null: false

      def resolve
        require_authentication!

        current_user = context[:current_user]
        stats = current_user.referral_stats
        earnings = current_user.earnings_as_referrer

        {
          referral_code: current_user.referral_code&.code,
          total_referrals: stats[:total_referrals],
          total_earnings: stats[:total_earnings],
          claimable_earnings: stats[:claimable_earnings],
          claimed_earnings: stats[:claimed_earnings],
          recent_earnings: earnings.order(created_at: :desc).limit(10)
        }
      end
    end
  end
end
