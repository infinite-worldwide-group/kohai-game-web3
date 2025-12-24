# frozen_string_literal: true

module Mutations
  module Users
    class AuthenticateWallet < Types::BaseMutation
      description "Authenticate user with wallet address"

      argument :wallet_address, String, required: true
      argument :signature, String, required: false
      argument :message, String, required: false
      argument :email, String, required: false
      argument :email_verified, Boolean, required: false

      field :user, Types::UserType, null: true
      field :token, String, null: true
      field :errors, [String], null: false
      field :message, String, null: true

      def resolve(wallet_address:, signature: nil, message: nil, email: nil, email_verified: false)
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
          # Find or create user by wallet address ONLY (email is handled separately below)
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

        # Handle OAuth email capture (e.g., from Google login)
        response_message = nil
        if email.present?
          result = capture_oauth_email(user, email, email_verified)
          response_message = result[:message]

          # If email capture failed, include error but still allow authentication
          if !result[:success]
            Rails.logger.warn "Email capture failed for user #{user.id}: #{response_message}"
          end
        end

        # Generate JWT token
        token = SolanaAuthService.generate_token(user)

        {
          user: user,
          token: token,
          errors: [],
          message: response_message
        }
      rescue SolanaAuthService::InvalidSignature, SolanaAuthService::ExpiredNonce => e
        {
          user: nil,
          token: nil,
          errors: [e.message],
          message: nil
        }
      rescue StandardError => e
        Rails.logger.error "Authentication failed: #{e.message}\n#{e.backtrace.join("\n")}"
        {
          user: nil,
          token: nil,
          errors: ["Authentication failed: #{e.message}"],
          message: nil
        }
      end

      private

      def capture_oauth_email(user, email, email_verified)
        # Normalize email (lowercase and strip whitespace)
        normalized_email = email.to_s.strip.downcase

        # Validate email format
        unless normalized_email.match?(URI::MailTo::EMAIL_REGEXP)
          return {
            success: false,
            message: "Invalid email format"
          }
        end

        # Check if email is already used by another user
        existing_user = ::User.where.not(id: user.id).find_by(email: normalized_email)
        if existing_user.present?
          return {
            success: false,
            message: "This email is already used by another user"
          }
        end

        # Check if user already has this email
        if user.email == normalized_email && user.email_verified?
          return {
            success: true,
            message: "Email already linked and verified"
          }
        end

        # Save email and mark as verified if from OAuth provider
        user.update!(
          email: normalized_email,
          email_verified_at: email_verified ? Time.current : nil
        )

        # Create audit log
        ::AuditLog.create!(
          user: user,
          action: 'oauth_email_captured',
          auditable: user,
          metadata: {
            email: normalized_email,
            email_verified: email_verified,
            captured_at: Time.current,
            source: 'oauth_login'
          }
        )

        {
          success: true,
          message: email_verified ? "Email automatically linked and verified" : "Email linked (verification required)"
        }
      rescue StandardError => e
        Rails.logger.error "OAuth email capture failed: #{e.message}\n#{e.backtrace.join("\n")}"
        {
          success: false,
          message: "Failed to save email: #{e.message}"
        }
      end
    end
  end
end
