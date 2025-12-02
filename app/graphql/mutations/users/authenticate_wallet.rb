# frozen_string_literal: true

module Mutations
  module Users
    class AuthenticateWallet < Types::BaseMutation
      description "Authenticate user with wallet address"

      argument :wallet_address, String, required: true
      argument :signature, String, required: false
      argument :message, String, required: false

      field :user, Types::UserType, null: true
      field :token, String, null: true
      field :errors, [String], null: false

      def resolve(wallet_address:, signature: nil, message: nil)
        # Two authentication modes:
        # 1. Simple mode: Just wallet address (signature optional)
        # 2. Secure mode: Wallet address + signature + message

        if signature.present? && message.present?
          # Full signature verification
          user = SolanaAuthService.authenticate(
            wallet_address: wallet_address,
            signature: signature,
            message: message
          )
        else
          # Simple wallet connection
          # Find or create user by wallet address
          user = ::User.find_or_create_by!(wallet_address: wallet_address)

          # Create audit log
          ::AuditLog.create(
            user_id: user.id,
            action: 'wallet_connection',
            auditable: user,
            metadata: {
              wallet_address: wallet_address,
              connected_at: Time.current,
              method: 'wallet_connect'
            }
          )
        end

        # Generate JWT token
        token = SolanaAuthService.generate_token(user)

        {
          user: user,
          token: token,
          errors: []
        }
      rescue SolanaAuthService::InvalidSignature, SolanaAuthService::ExpiredNonce => e
        {
          user: nil,
          token: nil,
          errors: [e.message]
        }
      rescue StandardError => e
        Rails.logger.error "Authentication failed: #{e.message}\n#{e.backtrace.join("\n")}"
        {
          user: nil,
          token: nil,
          errors: ["Authentication failed: #{e.message}"]
        }
      end
    end
  end
end
