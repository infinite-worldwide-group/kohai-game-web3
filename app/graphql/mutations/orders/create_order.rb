# frozen_string_literal: true

module Mutations
  module Orders
    class CreateOrder < Types::BaseMutation
      description "Create an order with verified crypto payment"

      argument :topup_product_item_id, ID, required: true
      argument :transaction_signature, String, required: true
      argument :user_data, GraphQL::Types::JSON, required: false

      field :order, Types::OrderType, null: true
      field :errors, [String], null: false

      def resolve(topup_product_item_id:, transaction_signature:, user_data: {})
        require_authentication!

        # Find product item
        product_item = ::TopupProductItem.find(topup_product_item_id)
        raise GraphQL::ExecutionError, "Product not found" unless product_item

        # Check if product is active
        unless product_item.active
          raise GraphQL::ExecutionError, "Product is not available"
        end

        # Calculate tier discount (in fiat currency)
        pricing = TierService.calculate_discounted_price(product_item.price, current_user)
        final_amount_usd = pricing[:final_price]  # Price in USD after discount
        original_amount_usd = pricing[:original_price]  # Original price in USD
        discount_amount = pricing[:discount_amount]
        discount_percent = pricing[:discount_percent]
        tier_info = pricing[:tier_info]

        # Convert USD to SOL for blockchain payment
        final_amount_sol = CurrencyConversionService.usd_to_sol(final_amount_usd)

        # Get platform wallet address
        platform_wallet = ENV.fetch('PLATFORM_WALLET_ADDRESS')

        Rails.logger.info "Creating order: tx=#{transaction_signature[0..8]}... amount=#{final_amount_sol} SOL"

        # Create order immediately, verify transaction in background after delay
        order = nil
        ActiveRecord::Base.transaction do
          # Create order
          order = ::Order.create!(
            user: current_user,
            topup_product_item: product_item,
            # Fiat amounts (for display/accounting)
            amount: final_amount_usd,
            original_amount: original_amount_usd,
            currency: product_item.currency, # USD, MYR, etc.
            # Crypto amounts (actual payment from blockchain)
            crypto_amount: final_amount_sol,
            crypto_currency: 'SOL',
            # Discount info
            discount_amount: discount_amount,
            discount_percent: discount_percent,
            tier_at_purchase: tier_info[:tier_name],
            # Other fields
            order_type: 'topup',
            user_data: user_data,
            status: 'pending'
          )

          # Create crypto transaction record with pending state
          crypto_tx = ::CryptoTransaction.create!(
            order: order,
            transaction_signature: transaction_signature,
            wallet_from: current_user.wallet_address,
            wallet_to: platform_wallet,
            amount: final_amount_sol,
            token: 'SOL',
            network: 'solana',
            decimals: 9,
            transaction_type: 'payment',
            direction: 'inbound',
            state: 'pending' # Will be verified by background job
          )

          # Create audit log
          ::AuditLog.create!(
            user: current_user,
            action: 'order_created',
            auditable: order,
            metadata: {
              order_number: order.order_number,
              transaction_signature: transaction_signature,
              amount: order.amount,
              currency: order.currency
            }
          )
        end

        # Enqueue transaction verification after 10 seconds
        # This gives the blockchain RPC time to index the transaction
        VerifyTransactionJob.set(wait: 10.seconds).perform_later(order.id)

        {
          order: order,
          errors: []
        }
      rescue ActiveRecord::RecordInvalid => e
        {
          order: nil,
          errors: e.record.errors.full_messages
        }
      rescue ActiveRecord::RecordNotUnique => e
        if e.message.include?('transaction_signature')
          {
            order: nil,
            errors: ["This transaction has already been used for an order"]
          }
        else
          {
            order: nil,
            errors: ["Duplicate order detected"]
          }
        end
      rescue StandardError => e
        Rails.logger.error "Order creation failed: #{e.message}\n#{e.backtrace.join("\n")}"
        {
          order: nil,
          errors: ["Failed to create order: #{e.message}"]
        }
      end
    end
  end
end
