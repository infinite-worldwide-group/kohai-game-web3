# frozen_string_literal: true

module Queries
  module Transactions
    class TransactionStatus < Queries::BaseQuery
      description "Check transaction status on blockchain"

      type Types::TransactionStatusType, null: true

      argument :signature, String, required: true

      def resolve(signature:)
        status = SolanaTransactionService.check_status(signature)
        {
          signature: signature,
          status: status[:status],
          confirmations: status[:confirmations]
        }
      rescue StandardError => e
        {
          signature: signature,
          status: 'error',
          confirmations: 0,
          error: e.message
        }
      end
    end
  end
end
