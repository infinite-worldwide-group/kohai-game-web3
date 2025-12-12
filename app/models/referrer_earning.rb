class ReferrerEarning < ApplicationRecord
  belongs_to :referrer, class_name: 'User', foreign_key: 'referrer_id'
  belongs_to :referred_user, class_name: 'User', foreign_key: 'referred_user_id'
  belongs_to :order
  belongs_to :referral

  validates :commission_amount, presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: %w[pending claimable claimed failed] }

  scope :pending, -> { where(status: 'pending') }
  scope :claimable, -> { where(status: 'claimable') }
  scope :claimed, -> { where(status: 'claimed') }
  scope :for_referrer, ->(user) { where(referrer: user) }

  # State machine transitions
  def mark_claimable!
    update!(status: 'claimable')
  end

  def mark_claimed!(transaction_signature)
    update!(
      status: 'claimed',
      claimed_at: Time.current,
      claim_transaction_signature: transaction_signature
    )
  end

  def self.total_claimable_for_referrer(referrer)
    claimable.for_referrer(referrer).sum(:commission_amount)
  end
end
