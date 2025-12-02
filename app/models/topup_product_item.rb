class TopupProductItem < ApplicationRecord
  # Associations
  belongs_to :topup_product
  has_many :orders, dependent: :nullify

  # Validations
  validates :topup_product, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_product, ->(product_id) { where(topup_product_id: product_id) }
  scope :ordered_by_price, -> { order(price: :asc) }

  # Instance methods
  def display_name
    name.presence || "Item ##{id}"
  end

  def formatted_price
    return 'N/A' if price.nil?
    "#{price} SOL"
  end
end
