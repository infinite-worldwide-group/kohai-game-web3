# frozen_string_literal: true

module Mutations
  module Orders
    class CreateOrder < Types::BaseMutation
      description "Create an order with verified crypto payment"

      argument :topup_product_item_id, ID, required: true
      argument :transaction_signature, String, required: true
      argument :game_account_id, ID, required: false
      argument :user_data, GraphQL::Types::JSON, required: false
      argument :crypto_currency, String, required: false
      argument :crypto_amount, Float, required: false

      field :order, Types::OrderType, null: true
      field :errors, [String], null: false

      def resolve(topup_product_item_id:, transaction_signature:, game_account_id: nil, user_data: {}, crypto_currency: 'USDT', crypto_amount: nil)
        require_authentication!

        # Find product item
        product_item = ::TopupProductItem.find(topup_product_item_id)
        raise GraphQL::ExecutionError, "Product not found" unless product_item

        # Check if product is active
        unless product_item.active
          raise GraphQL::ExecutionError, "Product is not available"
        end

        # Validate and auto-verify game account if provided
        game_account = nil
        if game_account_id.present?
          game_account = current_user.game_accounts.find_by(id: game_account_id)

          unless game_account
            return {
              order: nil,
              errors: ["Game account not found"]
            }
          end

          # Auto-verify game account if not already approved
          unless game_account.approved?
            validation_success = game_account.validate_with_vendor!
            game_account.reload

            unless validation_success && game_account.approved?
              return {
                order: nil,
                errors: ["Game account verification failed. Please verify your game account details."]
              }
            end
          end
        end

        # Convert product price from MYR to USDT using BigDecimal for precision
        price_in_usdt = if product_item.currency == 'MYR'
          BigDecimal(CurrencyConversionService.myr_to_usdt(product_item.price).to_s)
        else
          BigDecimal(product_item.price.to_s)
        end

        # Calculate tier discount (in USDT) - ensure BigDecimal precision
        pricing = TierService.calculate_discounted_price(price_in_usdt.to_f, current_user)
        final_amount_usdt = BigDecimal(pricing[:final_price].to_s)  # Price in USDT after discount
        original_amount_usdt = BigDecimal(pricing[:original_price].to_s)  # Original price in USDT
        discount_amount = BigDecimal(pricing[:discount_amount].to_s)
        discount_percent = pricing[:discount_percent]
        tier_info = pricing[:tier_info]

        # Use crypto_amount from frontend, or fallback to final_amount_usdt
        # Ensure it's converted to BigDecimal to preserve precision
        final_crypto_amount = if crypto_amount.present?
          BigDecimal(crypto_amount.to_s)
        else
          final_amount_usdt
        end
        crypto_token = crypto_currency.upcase

        # Log amounts for debugging
        Rails.logger.info "Order amounts - Original: #{original_amount_usdt}, Final: #{final_amount_usdt}, Crypto: #{final_crypto_amount} #{crypto_token}"

        # Get platform wallet address
        platform_wallet = ENV.fetch('PLATFORM_WALLET_ADDRESS')

        Rails.logger.info "Creating order: tx=#{transaction_signature[0..8]}... amount=#{final_crypto_amount} #{crypto_token}"

        # Create order immediately, verify transaction in background after delay
        order = nil
        ActiveRecord::Base.transaction do
          # Create order
          order = ::Order.create!(
            user: current_user,
            topup_product_item: product_item,
            game_account: game_account,
            # Fiat amounts (for display/accounting) - all in USDT
            amount: final_amount_usdt,
            original_amount: original_amount_usdt,
            currency: 'USDT', # Store as USDT (converted from MYR)
            # Crypto amounts (actual payment from blockchain)
            crypto_amount: final_crypto_amount,
            crypto_currency: crypto_token,
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
          # USDT on Solana uses 6 decimals
          token_decimals = crypto_token == 'USDT' ? 6 : 9

          crypto_tx = ::CryptoTransaction.create!(
            order: order,
            transaction_signature: transaction_signature,
            wallet_from: current_user.wallet_address,
            wallet_to: platform_wallet,
            amount: final_crypto_amount,
            token: crypto_token,
            network: 'solana',
            decimals: token_decimals,
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
