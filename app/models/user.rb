class User < ApplicationRecord
  # Associations
  has_many :orders, dependent: :destroy
  has_many :game_accounts, dependent: :destroy
  has_many :audit_logs, dependent: :nullify

  # Referral associations
  has_one :referral_code, dependent: :destroy
  has_many :referrals_given, class_name: 'Referral',
           foreign_key: 'referrer_id', dependent: :restrict_with_error
  has_one :referral_received, class_name: 'Referral',
          foreign_key: 'referred_user_id', dependent: :destroy
  belongs_to :referred_by, class_name: 'User', foreign_key: 'referred_by_id',
             optional: true

  # Voucher associations
  has_many :vouchers, dependent: :destroy

  # Earning associations
  has_many :earnings_as_referrer, class_name: 'ReferrerEarning',
           foreign_key: 'referrer_id', dependent: :restrict_with_error

  # Validations
  validates :wallet_address, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true, uniqueness: true

  # Callbacks
  before_save :normalize_wallet_address
  after_create :create_referral_code

  # Scopes
  scope :with_email, -> { where.not(email: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # Email verification
  AUTH_CODE_EXPIRY = 5.minutes

  def generate_auth_code!
    # Generate 6-digit code (000000-999999)
    self.auth_code = format('%06d', SecureRandom.random_number(1_000_000))
    self.updated_at = Time.current # Track when code was generated
    save!
    auth_code
  end

  def auth_code_valid?(code)
    return false if auth_code.blank?
    return false if code.blank?
    return false if auth_code_expired?

    auth_code == code.to_s
  end

  def auth_code_expired?
    return true if auth_code.blank?
    return true if updated_at.blank?

    updated_at < AUTH_CODE_EXPIRY.ago
  end

  def verify_email!
    update!(
      email_verified_at: Time.current,
      auth_code: nil
    )
  end

  def email_verified?
    email_verified_at.present?
  end

  def clear_auth_code!
    update!(auth_code: nil)
  end

  # Referral methods
  def active_vouchers
    vouchers.active.order(expires_at: :asc)
  end

  def total_claimable_earnings
    earnings_as_referrer.claimable.sum(:commission_amount)
  end

  def total_claimed_earnings
    earnings_as_referrer.claimed.sum(:commission_amount)
  end

  def referral_stats
    {
      total_referrals: referrals_given.count,
      total_earnings: earnings_as_referrer.sum(:commission_amount),
      claimable_earnings: total_claimable_earnings,
      claimed_earnings: total_claimed_earnings
    }
  end

  private

  def normalize_wallet_address
    self.wallet_address = wallet_address.to_s.strip if wallet_address.present?
  end

  def create_referral_code
    ReferralCode.create!(user: self)
  end
end
