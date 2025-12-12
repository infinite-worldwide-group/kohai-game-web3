# frozen_string_literal: true

module ReferralService
  extend self

  def apply_referral_code(user:, code:)
    # Validate user hasn't already used a referral
    if user.referred_by_id.present?
      return error_response("You have already used a referral code")
    end

    # Find referral code
    referral_code = ReferralCode.find_by(code: code.upcase.strip)
    return error_response("Invalid referral code") unless referral_code

    # Prevent self-referral
    if referral_code.user_id == user.id
      return error_response("You cannot use your own referral code")
    end

    # Create referral relationship
    referral = Referral.create(
      referrer: referral_code.user,
      referred_user: user,
      referral_code: referral_code,
      applied_at: Time.current
    )

    if referral.persisted?
      success_response(
        referral: referral,
        voucher: referral.voucher,
        message: "Referral code applied! You received a 10% discount voucher valid for 90 days."
      )
    else
      error_response(referral.errors.full_messages.join(", "))
    end
  rescue => e
    Rails.logger.error("ReferralService error: #{e.message}")
    error_response("Failed to apply referral code: #{e.message}")
  end

  def calculate_referrer_commission(order:)
    return { commission_percent: 0, commission_amount: 0 } unless order.user.referred_by_id.present?

    referrer = order.user.referred_by
    tier_info = TierService.check_tier_status(referrer)
    commission_percent = tier_info[:referral_percent] || 0

    return { commission_percent: 0, commission_amount: 0 } if commission_percent.zero?

    commission_amount = (order.crypto_amount * commission_percent / 100.0).round(8)

    {
      commission_percent: commission_percent,
      commission_amount: commission_amount,
      referrer_tier: tier_info[:tier_name],
      currency: order.crypto_currency
    }
  end

  private

  def success_response(data)
    { success: true }.merge(data)
  end

  def error_response(message)
    { success: false, error: message }
  end
end
