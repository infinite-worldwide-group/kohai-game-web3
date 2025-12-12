# frozen_string_literal: true

module Mutations
  module Referrals
    class ClaimEarnings < Types::BaseMutation
      description "Claim accumulated referrer earnings (initiates smart contract transfer)"

      field :transaction_signature, String, null: true
      field :claimed_amount, Float, null: true
      field :message, String, null: true
      field :errors, [String], null: false

      def resolve
        require_authentication!

        claimable_earnings = current_user.earnings_as_referrer.claimable

        if claimable_earnings.empty?
          return {
            transaction_signature: nil,
            claimed_amount: 0,
            message: "No earnings available to claim",
            errors: []
          }
        end

        total_amount = claimable_earnings.sum(:commission_amount)

        # TODO Phase 2: Integrate with smart contract vault
        # For now, use VaultService placeholder
        vault_result = VaultService.claim_earnings(
          user: current_user,
          amount: total_amount,
          currency: claimable_earnings.first.currency
        )

        if vault_result[:success]
          transaction_signature = vault_result[:transaction_signature]

          claimable_earnings.each do |earning|
            earning.mark_claimed!(transaction_signature)
          end

          {
            transaction_signature: transaction_signature,
            claimed_amount: total_amount.to_f,
            message: "Claim initiated. Funds will be transferred from vault.",
            errors: []
          }
        else
          {
            transaction_signature: nil,
            claimed_amount: 0,
            message: nil,
            errors: [vault_result[:error]]
          }
        end
      rescue => e
        Rails.logger.error("ClaimEarnings error: #{e.message}")
        {
          transaction_signature: nil,
          claimed_amount: 0,
          message: nil,
          errors: ["Failed to claim earnings: #{e.message}"]
        }
      end
    end
  end
end
