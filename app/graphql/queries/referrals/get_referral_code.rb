# frozen_string_literal: true

module Queries
  module Referrals
    class GetReferralCode < Queries::BaseQuery
      type Types::ReferralCodeType, null: true

      def resolve
        require_authentication!
        context[:current_user].referral_code
      end
    end
  end
end
