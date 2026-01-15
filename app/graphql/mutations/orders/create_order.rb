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

        # Validate payment currency - only USDT is accepted
        unless crypto_currency.to_s.upcase == 'USDT'
          return {
            order: nil,
            errors: ["Only USDT payments are accepted. Please pay with USDT."]
          }
        end

        # Check vendor balance - block purchase if balance < 100
        begin
          balance_response = VendorService.get_balance
          vendor_balance = balance_response['balance'] || balance_response['credit'] || balance_response.dig('data', 'balance') || 0
          if vendor_balance.to_f < 100
            return {
              order: nil,
              errors: ["Our products is currently unavailable. Please try again later."]
            }
          end
        rescue => e
          Rails.logger.error "Vendor balance check failed: #{e.message}"
          return {
            order: nil,
            errors: ["Our products is currently unavailable. Please try again later."]
          }
        end

        # Get topup product for validation
        topup_product = product_item.topup_product

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
            begin
              validation_response = VendorService.validate_game_account(
                product_id: topup_product&.origin_id || topup_product&.code,
                user_data: game_account.user_data || {}
              )
              # Check for maintenance error
              if validation_response.is_a?(Hash) && (validation_response['statusCode'] == 422 || validation_response['error'] == 'Maintenance')
                return {
                  order: nil,
                  errors: [validation_response['message'] || "This product is currently unavailable. Please try again later."]
                }
              end
              if validation_response && validation_response["data"] && validation_response["data"]["ign"].present?
                game_account.update!(approve: true, in_game_name: validation_response["data"]["ign"])
              else
                return {
                  order: nil,
                  errors: ["Game account verification failed. Please verify your game account details."]
                }
              end
            rescue => e
              Rails.logger.error "Game account validation failed: #{e.message}"
              return {
                order: nil,
                errors: ["Game account verification failed. Please try again."]
              }
            end
          end
        elsif user_data.present?
          # Validate game account with vendor when user_data is provided directly
          if topup_product&.origin_id.present?
            begin
              validation_response = VendorService.validate_game_account(
                product_id: topup_product.origin_id,
                user_data: user_data
              )
              # Check for maintenance error
              if validation_response.is_a?(Hash) && (validation_response['statusCode'] == 422 || validation_response['error'] == 'Maintenance')
                return {
                  order: nil,
                  errors: [validation_response['message'] || "This product is currently unavailable. Please try again later."]
                }
              end
              unless validation_response && validation_response["data"] && validation_response["data"]["ign"].present?
                return {
                  order: nil,
                  errors: ["Game account verification failed. Please verify your game account details."]
                }
              end
            rescue => e
              Rails.logger.error "Game account validation failed: #{e.message}"
              return {
                order: nil,
                errors: ["Game account verification failed. Please try again."]
              }
            end
          end
        end

        # Use product item's original price and currency for amount/original_amount
        # These fields record the product price in its original currency (e.g., MYR)
        final_amount = BigDecimal(product_item.price.to_s)
        original_amount = BigDecimal(product_item.price.to_s)
        order_currency = product_item.currency || 'USDT'
        
        # Use crypto_amount from frontend for the actual crypto payment
        # Frontend has already calculated the correct crypto amount with exchange rates and discounts
        final_crypto_amount = if crypto_amount.present?
          BigDecimal(crypto_amount.to_s)
        else
          # Fallback: convert product price to USDT if crypto_amount not provided
          if product_item.currency == 'MYR'
            BigDecimal(CurrencyConversionService.myr_to_usdt(product_item.price).to_s)
          else
            BigDecimal(product_item.price.to_s)
          end
        end
        crypto_token = crypto_currency.upcase

        # Get best available discount (tier or voucher) using VoucherService
        discount_info = VoucherService.get_best_discount(
          user: current_user,
          original_price: final_amount.to_f
        )

        # Extract discount information
        discount_amount = BigDecimal(discount_info[:discount_amount].to_s)
        discount_percent = discount_info[:discount_percent]
        discount_source = discount_info[:source]
        selected_voucher = discount_info[:voucher]
        tier_info = discount_info[:tier_info]

        # Apply discount to final_amount (MYR price)
        final_amount = BigDecimal(discount_info[:final_price].to_s)

        # Recalculate crypto_amount from discounted MYR price if not provided by frontend
        if crypto_amount.blank?
          if product_item.currency == 'MYR'
            final_crypto_amount = BigDecimal(
              CurrencyConversionService.myr_to_usdt(final_amount).to_s
            )
          else
            final_crypto_amount = final_amount
          end
        end

        # Log discount application
        Rails.logger.info "DISCOUNT_APPLIED source=#{discount_source} discount=#{discount_percent}% " \
                          "original=#{original_amount} final=#{final_amount} " \
                          "voucher_id=#{selected_voucher&.id} tier=#{tier_info[:tier_name]}"
        Rails.logger.info "Order amounts - Original: #{original_amount} #{order_currency}, Product: #{final_amount} #{order_currency}, Crypto: #{final_crypto_amount} #{crypto_token}"

        # Get platform wallet address
        platform_wallet = ENV.fetch('PLATFORM_WALLET_ADDRESS')

        # Generate order number early for vendor reference
        generated_order_number = "ORD-#{Time.now.to_i}-#{SecureRandom.hex(4).upcase}"
        callback_url = "https://#{ENV.fetch('DEFAULT_URL')}/api/vendor/callback"

        # Get user input data for vendor
        vendor_user_input = user_data.presence || game_account&.user_data || {}

        # Call vendor BEFORE creating order - only create order if vendor succeeds
        vendor_invoice_id = nil
        vendor_metadata = nil
        begin
          Rails.logger.info "Calling vendor to create order: #{generated_order_number}"
          vendor_response = VendorService.create_order(
            product_id: topup_product.origin_id,
            product_item_id: product_item.origin_id,
            user_input: vendor_user_input,
            partner_order_id: generated_order_number,
            callback_url: callback_url,
            price_usdt: final_crypto_amount
          )

          # Check if vendor order succeeded
          is_success = vendor_response['success'] == true ||
                       vendor_response['status']&.downcase == 'success' ||
                       vendor_response['statusCode'].to_i.between?(200, 299) ||
                       vendor_response['message'].to_s.downcase.include?('successful')

          unless is_success
            error_msg = vendor_response['message'] || vendor_response['error'] || 'Vendor order failed'
            Rails.logger.error "Vendor order creation failed: #{error_msg}"
            return {
              order: nil,
              errors: [error_msg]
            }
          end

          # Extract invoice/reference ID from response
          vendor_invoice_id = vendor_response['orderId'] || vendor_response['order_id'] ||
                              vendor_response['invoiceId'] || vendor_response['reference']
          vendor_metadata = vendor_response.to_json

          Rails.logger.info "Vendor order created successfully: invoice_id=#{vendor_invoice_id}"

        rescue => e
          Rails.logger.error "Vendor order creation failed: #{e.message}"
          return {
            order: nil,
            errors: ["Unable to process order. Please try again later."]
          }
        end

        Rails.logger.info "Creating order: tx=#{transaction_signature[0..8]}... amount=#{final_crypto_amount} #{crypto_token}"

        # Create order only after vendor succeeds
        order = nil
        ActiveRecord::Base.transaction do
          # Create order
          order = ::Order.create!(
            user: current_user,
            topup_product_item: product_item,
            game_account: game_account,
            voucher: selected_voucher,
            # Use pre-generated order number (already sent to vendor)
            order_number: generated_order_number,
            # Product price in original currency (e.g., 0.04 MYR)
            amount: final_amount,
            original_amount: original_amount,
            currency: order_currency, # Original currency (e.g., 'MYR')
            # Crypto amounts (actual payment from blockchain, e.g., 0.008511 USDT)
            crypto_amount: final_crypto_amount,
            crypto_currency: crypto_token,
            # Discount info
            discount_amount: discount_amount,
            discount_percent: discount_percent,
            tier_at_purchase: tier_info[:tier_name],
            voucher_discount_percent: selected_voucher&.discount_percent,
            voucher_discount_amount: discount_source == 'voucher' ? discount_amount : 0,
            final_discount_source: discount_source,
            # Other fields
            order_type: 'topup',
            user_data: user_data,
            # Vendor already has the order, set to processing with invoice_id
            status: 'processing',
            invoice_id: vendor_invoice_id,
            metadata: vendor_metadata
          )

          # Mark voucher as used if applied
          if selected_voucher.present?
            VoucherService.apply_voucher_to_order(voucher: selected_voucher, order: order)
          end

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

        # Note: order.process! is NOT called because vendor purchase was done BEFORE creating the order.
        # The order is already in 'processing' status with invoice_id set.

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
