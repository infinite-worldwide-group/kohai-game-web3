class VerificationCache < ApplicationRecord
  # Associations
  belongs_to :order

  # Validations
  validates :transaction_signature, presence: true, uniqueness: true

  # Scopes
  scope :verified, -> { where(verification_status: 'verified') }
  scope :pending, -> { where(verification_status: 'pending') }
  scope :failed, -> { where(verification_status: 'failed') }
  scope :recent, -> { order(last_verified_at: :desc) }

  # Instance methods
  def verified?
    verification_status == 'verified'
  end

  def needs_verification?
    last_verified_at.nil? || last_verified_at < 5.minutes.ago
  end

  def mark_verified!(confirmations_count = 0)
    update(
      verification_status: 'verified',
      confirmations: confirmations_count,
      last_verified_at: Time.current
    )
  end

  def mark_failed!
    update(
      verification_status: 'failed',
      last_verified_at: Time.current
    )
  end
end
