# frozen_string_literal: true

module Mutations
  module Users
    class GenerateNonce < Types::BaseMutation
      description "Generate a nonce for wallet authentication"

      argument :wallet_address, String, required: true

      field :message, String, null: false
      field :nonce, String, null: false
      field :errors, [String], null: false

      def resolve(wallet_address:)
        result = SolanaAuthService.generate_nonce(wallet_address)

        {
          message: result[:message],
          nonce: result[:nonce],
          errors: []
        }
      rescue StandardError => e
        {
          message: "",
          nonce: "",
          errors: [e.message]
        }
      end
    end
  end
end
