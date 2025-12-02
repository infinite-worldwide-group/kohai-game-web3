class Order < ApplicationRecord
  include AASM

  # Associations
  belongs_to :user
  belongs_to :fiat_currency, optional: true
  belongs_to :topup_product_item, optional: true
  belongs_to :game_account, optional: true
  has_one :crypto_transaction, dependent: :destroy
  has_many :vendor_transaction_logs, dependent: :destroy

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true
  validates :order_type, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :topup_orders, -> { where(order_type: 'topup') }

  # AASM State Machine
  aasm column: 'status' do
    state :pending, initial: true
    state :paid
    state :processing
    state :succeeded
    state :completed
    state :failed
    state :cancelled

    event :pay do
      transitions from: :pending, to: :paid
    end

    event :process do
      transitions from: [:pending, :paid], to: :processing
      after :purchase_game_credit
    end

    event :success do
      transitions from: [:pending, :paid, :processing], to: :succeeded
    end

    event :complete do
      transitions from: :succeeded, to: :completed
    end

    event :fail do
      transitions from: [:pending, :paid, :processing], to: :failed
    end

    event :cancel do
      transitions from: :pending, to: :cancelled
    end
  end

  # Callbacks
  before_validation :generate_order_number, if: -> { order_number.blank? }, on: :create

  #private

  def generate_order_number
    self.order_number = "ORD-#{Time.now.to_i}-#{SecureRandom.hex(4).upcase}"
  end

  def purchase_game_credit
    # Skip if we've already purchased from vendor (invoice_id is set)
    return if invoice_id.present?

    # Only process topup orders that need vendor purchase
    return unless order_type == 'topup' && topup_product_item.present?

    # Call vendor service to purchase game credit
    OrderService.post_purchase(order: self)
  end


end
