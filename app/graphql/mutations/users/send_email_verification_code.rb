# frozen_string_literal: true

module Mutations
  module Users
    class SendEmailVerificationCode < Types::BaseMutation
      description "Send a verification code to the user's email address"

      argument :email, String, required: true

      field :success, Boolean, null: false
      field :message, String, null: false
      field :errors, [String], null: false

      def resolve(email:)
        require_authentication!

        # Validate email format
        unless email.match?(URI::MailTo::EMAIL_REGEXP)
          return {
            success: false,
            message: "Invalid email format",
            errors: ["Invalid email format"]
          }
        end

        # Check if email is already taken by another user
        if ::User.where.not(id: current_user.id).exists?(email: email)
          return {
            success: false,
            message: "This email is already registered to another account",
            errors: ["This email is already registered to another account"]
          }
        end

        # Update user's email (but not verified yet)
        current_user.update!(
          email: email,
          email_verified_at: nil
        )

        # Send verification code
        if EmailVerificationService.send_verification_code(user: current_user, email: email)
          {
            success: true,
            message: "Verification code sent to #{email}",
            errors: []
          }
        else
          {
            success: false,
            message: "Failed to send verification code. Please try again.",
            errors: ["Failed to send verification code"]
          }
        end
      rescue StandardError => e
        Rails.logger.error "Send email verification failed: #{e.message}\n#{e.backtrace.join("\n")}"
        {
          success: false,
          message: "An error occurred. Please try again.",
          errors: [e.message]
        }
      end
    end
  end
end
