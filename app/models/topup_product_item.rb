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
    "#{price} #{currency}"
  end

  # Calculate discounted price based on user tier
  # @param user [User] The user to calculate discount for
  # @return [Hash] { original_price:, discount_percent:, discount_amount:, discounted_price:, tier_info: }
  def calculate_user_discount(user)
    return {
      original_price: price,
      discount_percent: 0,
      discount_amount: 0,
      discounted_price: price,
      tier_info: nil
    } unless user.present?

    tier_info = TierService.check_tier_status(user)
    discount_percent = tier_info[:discount_percent] || 0

    discount_amount = (price * discount_percent / 100.0).round(2)
    discounted_price = (price - discount_amount).round(2)

    {
      original_price: price,
      discount_percent: discount_percent,
      discount_amount: discount_amount,
      discounted_price: discounted_price,
      tier_info: tier_info
    }
  end

  # Get price in USDT with discount
  # @param user [User] The user to calculate discount for
  # @return [Float] Discounted price in USDT
  def discounted_price_usdt(user)
    discount_info = calculate_user_discount(user)
    discounted_price_myr = discount_info[:discounted_price]

    if currency == 'MYR'
      CurrencyConversionService.myr_to_usdt(discounted_price_myr)
    else
      # Assume USD/USDT if not MYR
      discounted_price_myr
    end
  end
end
