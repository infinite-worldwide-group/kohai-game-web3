class Referral < ApplicationRecord
  belongs_to :referrer, class_name: 'User', foreign_key: 'referrer_id'
  belongs_to :referred_user, class_name: 'User', foreign_key: 'referred_user_id'
  belongs_to :referral_code
  has_one :voucher, dependent: :destroy
  has_many :referrer_earnings, dependent: :destroy

  validates :referred_user_id, uniqueness: true
  validate :cannot_refer_self
  validate :referrer_matches_code

  after_create :create_welcome_voucher
  after_create :update_user_referral_info

  private

  def cannot_refer_self
    errors.add(:base, "Cannot refer yourself") if referrer_id == referred_user_id
  end

  def referrer_matches_code
    return unless referral_code && referrer

    unless referral_code.user_id == referrer_id
      errors.add(:base, "Referral code does not belong to referrer")
    end
  end

  def create_welcome_voucher
    Voucher.create!(
      user: referred_user,
      referral: self,
      voucher_type: 'referral_welcome',
      discount_percent: 10.0,
      expires_at: 90.days.from_now
    )
  end

  def update_user_referral_info
    referred_user.update(
      referred_by_id: referrer_id,
      referral_applied_at: Time.current
    )
    referral_code.increment!(:total_uses)
  end
end
