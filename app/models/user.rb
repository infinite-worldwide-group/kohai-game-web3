class User < ApplicationRecord
  # Associations
  has_many :orders, dependent: :destroy
  has_many :game_accounts, dependent: :destroy
  has_many :audit_logs, dependent: :nullify

  # Validations
  validates :wallet_address, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true, uniqueness: true

  # Callbacks
  before_save :normalize_wallet_address

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

  private

  def normalize_wallet_address
    self.wallet_address = wallet_address.to_s.strip if wallet_address.present?
  end
end
