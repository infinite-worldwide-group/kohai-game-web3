class CryptoTransaction < ApplicationRecord
  include AASM

  # Associations
  belongs_to :order

  # Validations
  validates :transaction_signature, presence: true, uniqueness: true
  validates :token, presence: true
  validates :network, presence: true
  validates :transaction_type, presence: true, inclusion: { in: %w[payment refund] }
  validates :direction, presence: true, inclusion: { in: %w[inbound outbound] }
  validates :state, presence: true

  # Scopes
  scope :pending, -> { where(state: 'pending') }
  scope :confirmed, -> { where(state: 'confirmed') }
  scope :failed, -> { where(state: 'failed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_network, ->(network) { where(network: network) }
  scope :inbound, -> { where(direction: 'inbound') }
  scope :outbound, -> { where(direction: 'outbound') }

  # AASM State Machine
  aasm column: 'state' do
    state :pending, initial: true
    state :confirmed
    state :failed
    state :expired

    event :confirm do
      transitions from: :pending, to: :confirmed
      after do
        update(verified_at: Time.current)
        order&.pay! if order&.may_pay?
      end
    end

    event :fail do
      transitions from: :pending, to: :failed
    end

    event :expire do
      transitions from: :pending, to: :expired
    end
  end

  # Instance methods
  def verified?
    confirmed?
  end

  def pending?
    state == 'pending'
  end

  def confirmed?
    state == 'confirmed'
  end
end
