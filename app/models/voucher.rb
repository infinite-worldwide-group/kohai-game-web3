class Voucher < ApplicationRecord
  belongs_to :user
  belongs_to :referral, optional: true
  belongs_to :order, optional: true

  validates :voucher_type, presence: true
  validates :discount_percent, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :expires_at, presence: true

  scope :active, -> { where(used: false).where('expires_at > ?', Time.current) }
  scope :expired, -> { where(used: false).where('expires_at <= ?', Time.current) }
  scope :used, -> { where(used: true) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_type, ->(type) { where(voucher_type: type) }

  def active?
    !used && expires_at > Time.current
  end

  def use!(order)
    raise "Voucher already used" if used?
    raise "Voucher expired" if expired?

    update!(
      used: true,
      used_at: Time.current,
      order: order
    )
  end

  def expired?
    expires_at <= Time.current
  end
end
