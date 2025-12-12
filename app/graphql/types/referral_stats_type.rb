# frozen_string_literal: true

module Types
  class ReferralStatsType < Types::BaseObject
    field :referral_code, String, null: true
    field :total_referrals, Integer, null: false
    field :total_earnings, Float, null: false
    field :claimable_earnings, Float, null: false
    field :claimed_earnings, Float, null: false
    field :recent_earnings, [Types::ReferrerEarningType], null: false
  end
end
