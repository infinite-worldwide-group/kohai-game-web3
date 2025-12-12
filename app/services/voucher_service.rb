# frozen_string_literal: true

module VoucherService
  extend self

  def get_best_discount(user:, original_price:)
    # Get tier discount
    tier_info = TierService.check_tier_status(user)
    tier_discount = tier_info[:discount_percent]

    # Get best active voucher
    best_voucher = user.active_vouchers.order(discount_percent: :desc).first
    voucher_discount = best_voucher&.discount_percent || 0

    # Determine which discount to use (take maximum)
    if voucher_discount > tier_discount
      {
        source: 'voucher',
        discount_percent: voucher_discount,
        discount_amount: (original_price * voucher_discount / 100.0).round(8),
        final_price: (original_price * (100 - voucher_discount) / 100.0).round(8),
        voucher: best_voucher,
        tier_info: tier_info
      }
    else
      {
        source: 'tier',
        discount_percent: tier_discount,
        discount_amount: (original_price * tier_discount / 100.0).round(8),
        final_price: (original_price * (100 - tier_discount) / 100.0).round(8),
        voucher: nil,
        tier_info: tier_info
      }
    end
  end

  def apply_voucher_to_order(voucher:, order:)
    return error_response("Voucher not active") unless voucher.active?
    return error_response("Voucher not owned by user") unless voucher.user_id == order.user_id

    voucher.use!(order)
    success_response(message: "Voucher applied successfully")
  rescue => e
    Rails.logger.error("VoucherService error: #{e.message}")
    error_response("Failed to apply voucher: #{e.message}")
  end

  def create_promotional_voucher(user:, discount_percent:, expires_at:, voucher_type: 'promotional')
    Voucher.create!(
      user: user,
      voucher_type: voucher_type,
      discount_percent: discount_percent,
      expires_at: expires_at
    )
  end

  private

  def success_response(data)
    { success: true }.merge(data)
  end

  def error_response(message)
    { success: false, error: message }
  end
end
