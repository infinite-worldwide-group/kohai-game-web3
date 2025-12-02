# frozen_string_literal: true

module Mutations
  module Users
    class VerifyEmail < Types::BaseMutation
      description "Verify user's email with the 6-digit code"

      argument :code, String, required: true

      field :success, Boolean, null: false
      field :message, String, null: false
      field :errors, [String], null: false
      field :user, Types::UserType, null: true

      def resolve(code:)
        require_authentication!

        # Check if user has an email
        unless current_user.email.present?
          return {
            success: false,
            message: "No email address found. Please add an email first.",
            errors: ["No email address found"],
            user: nil
          }
        end

        # Verify the code
        result = EmailVerificationService.verify_code(user: current_user, code: code)

        if result[:success]
          # Create audit log
          ::AuditLog.create!(
            user: current_user,
            action: 'email_verified',
            auditable: current_user,
            metadata: {
              email: current_user.email,
              verified_at: current_user.email_verified_at
            }
          )

          {
            success: true,
            message: result[:message],
            errors: [],
            user: current_user.reload
          }
        else
          {
            success: false,
            message: result[:message],
            errors: [result[:message]],
            user: nil
          }
        end
      rescue StandardError => e
        Rails.logger.error "Email verification failed: #{e.message}\n#{e.backtrace.join("\n")}"
        {
          success: false,
          message: "An error occurred. Please try again.",
          errors: [e.message],
          user: nil
        }
      end
    end
  end
end
