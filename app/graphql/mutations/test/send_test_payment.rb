# frozen_string_literal: true

module Mutations
  module Test
    class SendTestPayment < Types::BaseMutation
      description "Send a test payment with memo (for testing only)"

      argument :to_address, String, required: true
      argument :amount, Float, required: true
      argument :memo, String, required: true

      field :signature, String, null: true
      field :status, String, null: true
      field :errors, [String], null: false

      def resolve(to_address:, amount:, memo:)
        # Only allow in development/test
        unless Rails.env.development? || Rails.env.test?
          return {
            signature: nil,
            status: 'forbidden',
            errors: ['Test payments only allowed in development/test environment']
          }
        end

        result = SolanaTransactionBuilderService.send_sol_with_memo(
          to_address: to_address,
          amount_sol: amount,
          memo: memo
        )

        {
          signature: result[:signature],
          status: result[:status],
          errors: []
        }
      rescue StandardError => e
        {
          signature: nil,
          status: 'failed',
          errors: [e.message]
        }
      end
    end
  end
end
