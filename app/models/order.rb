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
  scope :topup_product, -> { where(order_type: 'topup_product') }
  scope :pending, -> { where(status: 'pending') }
  scope :succeeded, -> { where(status: 'succeeded') }

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

    # Validate transaction before proceeding
    unless validate_transaction
      fail!
      return false
    end

    # Call vendor service to purchase game credit
    OrderService.post_purchase(order: self)
  end

  def validate_transaction
    # Check if crypto transaction exists
    unless crypto_transaction.present?
      update(error_message: "No crypto transaction found for this order")
      Rails.logger.error("Order #{order_number}: No crypto transaction found")
      return false
    end

    # Get transaction signature
    signature = crypto_transaction.transaction_signature
    unless signature.present?
      update(error_message: "No transaction signature found")
      Rails.logger.error("Order #{order_number}: No transaction signature found")
      return false
    end

    begin
      # Get transaction details from Solana
      response = SolanaApi.get_transaction(signature)

      # Check if transaction was found
      if response['result'].nil?
        update(error_message: "Transaction not found on blockchain")
        Rails.logger.error("Order #{order_number}: Transaction #{signature} not found")
        return false
      end

      transaction_data = response['result']

      # Check if transaction was successful
      if transaction_data['meta']['err'].present?
        update(error_message: "Transaction failed on blockchain")
        Rails.logger.error("Order #{order_number}: Transaction #{signature} failed with error: #{transaction_data['meta']['err']}")
        return false
      end

      # Extract amount from transaction
      # The transaction amount is in the postTokenBalances - preTokenBalances
      meta = transaction_data['meta']

      # Use BigDecimal for expected amount to avoid precision issues
      expected_amount = BigDecimal(crypto_amount.to_s)
      
      Rails.logger.info("Order #{order_number}: Validating transaction amount")
      Rails.logger.info("  Expected: #{expected_amount} #{crypto_currency}")
      Rails.logger.info("  Currency: #{crypto_currency}")

      amount_transferred = nil
      
      if meta['postTokenBalances'].present? && meta['preTokenBalances'].present?
        # For SPL token transfers (USDT, USDC, etc.)
        post_balance = meta['postTokenBalances'].first
        pre_balance = meta['preTokenBalances'].first

        if post_balance && pre_balance
          # Calculate the difference in token amounts using BigDecimal
          post_amount = BigDecimal(post_balance['uiTokenAmount']['uiAmount'].to_s)
          pre_amount = BigDecimal(pre_balance['uiTokenAmount']['uiAmount'].to_s)
          amount_transferred = (post_amount - pre_amount).abs
          
          Rails.logger.info("  Blockchain amount: #{amount_transferred} (from SPL token balances)")
          
          # For USDT/USDC, allow smaller tolerance due to 6 decimals
          tolerance = crypto_currency == 'USDT' || crypto_currency == 'USDC' ? BigDecimal('0.000001') : BigDecimal('0.01')

          # Compare with crypto_amount
          difference = (amount_transferred - expected_amount).abs
          Rails.logger.info("  Difference: #{difference} (tolerance: #{tolerance})")
          
          if difference > tolerance
            error_msg = "Amount mismatch: blockchain has #{amount_transferred} #{crypto_currency}, order expects #{expected_amount} #{crypto_currency} (diff: #{difference})"
            update(error_message: error_msg)
            Rails.logger.error("Order #{order_number}: #{error_msg}")
            return false
          end
        end
      else
        # For SOL transfers, check preBalances and postBalances
        pre_balances = meta['preBalances'] || []
        post_balances = meta['postBalances'] || []

        if pre_balances.any? && post_balances.any?
          # Calculate amount transferred (in SOL) using BigDecimal
          amount_transferred_lamports = (pre_balances.first - post_balances.first).abs
          amount_transferred = BigDecimal(amount_transferred_lamports.to_s) / BigDecimal('1000000000')
          
          Rails.logger.info("  Blockchain amount: #{amount_transferred} SOL (from lamports)")
          
          # For SOL, use 0.001 tolerance (0.1% of typical transaction)
          tolerance = BigDecimal('0.001')
          difference = (amount_transferred - expected_amount).abs
          Rails.logger.info("  Difference: #{difference} SOL (tolerance: #{tolerance})")
          
          if difference > tolerance
            error_msg = "Amount mismatch: blockchain has #{amount_transferred} SOL, order expects #{expected_amount} SOL (diff: #{difference})"
            update(error_message: error_msg)
            Rails.logger.error("Order #{order_number}: #{error_msg}")
            return false
          end
        end
      end

      if amount_transferred.nil?
        update(error_message: "Could not extract transaction amount from blockchain data")
        Rails.logger.error("Order #{order_number}: No token balances found in transaction")
        return false
      end

      Rails.logger.info("Order #{order_number}: ✓ Transaction validation successful - Amount verified: #{amount_transferred} #{crypto_currency}")
      true

    rescue => e
      update(error_message: "Error validating transaction: #{e.message}")
      Rails.logger.error("Order #{order_number}: Error validating transaction #{signature}: #{e.message}")
      false
    end
  end

end
