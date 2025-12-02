class GameAccount < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :topup_product, optional: true
  has_many :orders, dependent: :nullify

  # Validations
  validates :account_id, presence: true
  validates :status, inclusion: { in: %w[active disabled] }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :disabled, -> { where(status: 'disabled') }
  scope :approved, -> { where(approve: true) }
  scope :pending_approval, -> { where(approve: false) }
  scope :by_game, ->(game_id) { where(game_id: game_id) }
  scope :by_product, ->(product_id) { where(topup_product_id: product_id) }
  scope :recent, -> { order(created_at: :desc) }

  # Default scope to only show active accounts
  default_scope { where(status: 'active') }

  # Instance methods
  def approved?
    approve == true
  end

  def active?
    status == 'active'
  end

  def disabled?
    status == 'disabled'
  end

  def disable!
    update!(status: 'disabled')
  end

  def enable!
    update!(status: 'active')
  end

  def display_name
    in_game_name.presence || account_id
  end

  # Validate game account with vendor
  def validate_with_vendor!
    return false unless topup_product&.code.present?

    response = VendorService.validate_game_account(
      product_id: topup_product.code,
      user_data: user_data || {}
    )

    if response && response["data"] && response["data"]["ign"].present?
      update!(
        approve: true,
        in_game_name: response["data"]["ign"]
      )
      true
    else
      false
    end
  rescue => e
    Rails.logger.error "Failed to validate game account #{id}: #{e.message}"
    false
  end
end
