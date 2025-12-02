# frozen_string_literal: true

class KohaiGameWeb3Schema < GraphQL::Schema
  mutation(Types::MutationType)
  query(Types::QueryType)

  # Handle errors gracefully
  rescue_from(ActiveRecord::RecordNotFound) do |err, obj, args, ctx, field|
    raise GraphQL::ExecutionError, "Record not found: #{err.message}"
  end

  rescue_from(ActiveRecord::RecordInvalid) do |err, obj, args, ctx, field|
    raise GraphQL::ExecutionError, err.record.errors.full_messages.join(", ")
  end

  rescue_from(SolanaAuthService::InvalidSignature) do |err, obj, args, ctx, field|
    raise GraphQL::ExecutionError, "Authentication failed: #{err.message}"
  end

  rescue_from(SolanaAuthService::ExpiredNonce) do |err, obj, args, ctx, field|
    raise GraphQL::ExecutionError, "Authentication nonce expired. Please request a new one."
  end

  rescue_from(SolanaTransactionService::TransactionNotFound) do |err, obj, args, ctx, field|
    raise GraphQL::ExecutionError, "Transaction not found on blockchain"
  end

  rescue_from(SolanaTransactionService::InvalidTransaction) do |err, obj, args, ctx, field|
    raise GraphQL::ExecutionError, "Invalid transaction: #{err.message}"
  end
end
