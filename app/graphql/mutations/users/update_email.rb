# frozen_string_literal: true

module Mutations
  module Users
    class UpdateEmail < Types::BaseMutation
      description "Update and re-verify user's email address"

      argument :new_email, String, required: true

      field :success, Boolean, null: false
      field :message, String, null: false
      field :errors, [String], null: false

      def resolve(new_email:)
        require_authentication!

        # Validate email format
        unless new_email.match?(URI::MailTo::EMAIL_REGEXP)
          return {
            success: false,
            message: "Invalid email format",
            errors: ["Invalid email format"]
          }
        end

        # Check if email is already taken by another user
        if ::User.where.not(id: current_user.id).exists?(email: new_email)
          return {
            success: false,
            message: "This email is already registered to another account",
            errors: ["This email is already registered to another account"]
          }
        end

        # Check if it's the same as current email
        if current_user.email == new_email
          return {
            success: false,
            message: "This is already your current email address",
            errors: ["This is already your current email address"]
          }
        end

        # Update email and reset verification
        current_user.update!(
          email: new_email,
          email_verified_at: nil,
          auth_code: nil
        )

        # Send verification code to new email
        if EmailVerificationService.send_verification_code(user: current_user, email: new_email)
          # Create audit log
          ::AuditLog.create!(
            user: current_user,
            action: 'email_updated',
            auditable: current_user,
            metadata: {
              new_email: new_email
            }
          )

          {
            success: true,
            message: "Email updated. Verification code sent to #{new_email}",
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
        Rails.logger.error "Update email failed: #{e.message}\n#{e.backtrace.join("\n")}"
        {
          success: false,
          message: "An error occurred. Please try again.",
          errors: [e.message]
        }
      end
    end
  end
end
