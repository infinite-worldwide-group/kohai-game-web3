class VendorTransactionLog < ApplicationRecord
  # Associations
  belongs_to :order

  # Validations
  validates :order, presence: true
  validates :vendor_name, presence: true
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :by_vendor, ->(vendor_name) { where(vendor_name: vendor_name) }
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'fail') }
  scope :recent, -> { order(executed_at: :desc) }

  # Instance methods
  def success?
    status == 'success'
  end

  def failed?
    status == 'fail'
  end

  def can_retry?
    failed? && retry_count < 3
  end
end
