# frozen_string_literal: true

module Mutations
  module Referrals
    class ApplyReferralCode < Types::BaseMutation
      description "Apply a referral code to receive a welcome voucher"

      argument :code, String, required: true

      field :referral, Types::ReferralType, null: true
      field :voucher, Types::VoucherType, null: true
      field :message, String, null: true
      field :errors, [String], null: false

      def resolve(code:)
        require_authentication!

        result = ReferralService.apply_referral_code(
          user: current_user,
          code: code
        )

        if result[:success]
          {
            referral: result[:referral],
            voucher: result[:voucher],
            message: result[:message],
            errors: []
          }
        else
          {
            referral: nil,
            voucher: nil,
            message: nil,
            errors: [result[:error]]
          }
        end
      end
    end
  end
end
