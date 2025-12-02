# frozen_string_literal: true

require 'net/http'
require 'json'

# Service for handling email verification using Resend
class EmailVerificationService
  class << self
    # Send verification code to user's email via Resend
    # @param user [User] The user to send code to
    # @param email [String] The email address to send to
    # @return [Boolean] Success status
    def send_verification_code(user:, email:)
      Rails.logger.info "=" * 80
      Rails.logger.info "EMAIL VERIFICATION - Starting to send code"
      Rails.logger.info "User ID: #{user.id}"
      Rails.logger.info "Email: #{email}"
      Rails.logger.info "Resend API Key present: #{ENV['RESEND_API_KEY'].present?}"
      Rails.logger.info "From Email: #{ENV.fetch('RESEND_FROM_EMAIL', 'onboarding@resend.dev')}"
      Rails.logger.info "=" * 80

      # Generate 6-digit code
      code = user.generate_auth_code!
      Rails.logger.info "Generated verification code: #{code}"

      # Send email via Resend API
      result = send_email_via_resend(email: email, code: code)

      Rails.logger.info "✅ Verification code sent successfully to #{email} for user #{user.id}"
      Rails.logger.info "Resend response: #{result.inspect}"
      true
    rescue StandardError => e
      Rails.logger.error "❌ Failed to send verification code to #{email}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error "Error message: #{e.message}"
      Rails.logger.error "Backtrace:\n#{e.backtrace.join("\n")}"
      false
    end

    # Verify the code provided by user
    # @param user [User] The user verifying
    # @param code [String] The verification code
    # @return [Hash] { success: Boolean, message: String }
    def verify_code(user:, code:)
      if user.auth_code.blank?
        return { success: false, message: 'No verification code found. Please request a new code.' }
      end

      if user.auth_code_expired?
        return { success: false, message: 'Verification code has expired. Please request a new code.' }
      end

      if user.auth_code_valid?(code)
        user.verify_email!
        { success: true, message: 'Email verified successfully!' }
      else
        { success: false, message: 'Invalid verification code. Please try again.' }
      end
    end

    private

    # Send email using Resend API
    def send_email_via_resend(email:, code:)
      resend_api_key = ENV.fetch('RESEND_API_KEY')
      from_email = ENV.fetch('RESEND_FROM_EMAIL', 'onboarding@resend.dev')

      Rails.logger.info "Preparing to send email to #{email}"
      Rails.logger.info "From: #{from_email}"

      uri = URI('https://api.resend.com/emails')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{resend_api_key}"
      request['Content-Type'] = 'application/json'

      email_body = {
        from: from_email,
        to: [email],
        subject: 'Verify Your Email - KOHAI Game',
        html: email_template(code)
      }

      request.body = email_body.to_json
      Rails.logger.info "Sending request to Resend API..."

      response = http.request(request)
      response_body = JSON.parse(response.body) rescue response.body

      Rails.logger.info "Resend API Response Code: #{response.code}"
      Rails.logger.info "Resend API Response Body: #{response_body.inspect}"

      if response.code.to_i == 200
        Rails.logger.info "✅ Email sent successfully via Resend to #{email}"
        response_body
      else
        error_msg = response_body.is_a?(Hash) ? response_body['message'] : response_body
        Rails.logger.error "❌ Resend API error: #{response.code} - #{error_msg}"
        raise "Failed to send email (#{response.code}): #{error_msg}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error "❌ Timeout connecting to Resend API: #{e.message}"
      raise "Email service timeout. Please try again."
    rescue StandardError => e
      Rails.logger.error "❌ Error sending email: #{e.class} - #{e.message}"
      raise e
    end

    # HTML email template
    def email_template(code)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .code-box { background: #f4f4f4; border: 2px solid #ddd; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0; }
            .code { font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #2563eb; }
            .footer { margin-top: 30px; font-size: 12px; color: #666; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Verify Your Email</h1>
            <p>Thank you for signing up with KOHAI Game! Please use the verification code below to verify your email address.</p>

            <div class="code-box">
              <div class="code">#{code}</div>
            </div>

            <p>This code will expire in 5 minutes.</p>
            <p>If you didn't request this code, please ignore this email.</p>

            <div class="footer">
              <p>© KOHAI Game. All rights reserved.</p>
            </div>
          </div>
        </body>
        </html>
      HTML
    end
  end
end
