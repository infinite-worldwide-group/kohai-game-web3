# frozen_string_literal: true

# Service to handle topup product checkout flow
module TopupProductService
  extend self

  # Checkout a topup product and create an order
  # @param user [User] The user making the purchase
  # @param checkout_input [Hash] Checkout input data
  # @param validation_data [Hash] Optional validation data from vendor
  # @return [Hash] Success/error response with checkout data
  def checkout(user:, checkout_input:, validation_data: {})
    begin
      topup_product_item = TopupProductItem.find(checkout_input[:id])
      topup_product = topup_product_item.topup_product

      # Validate product is active
      unless topup_product_item.active && topup_product.is_active
        return error_response('This product is currently unavailable')
      end

      # Get price in original currency (MYR)
      price_myr = topup_product_item.price

      # Convert price to USDT for the order
      # This ensures the vendor receives the amount in USDT, not MYR
      price_usdt = CurrencyConversionService.convert(
        price_myr,
        from_currency: topup_product_item.currency || 'MYR',
        to_currency: 'USDT'
      )

      # Ensure price is greater than 0
      if price_usdt <= 0
        Rails.logger.error "Converted price is 0 or negative: MYR #{price_myr} -> USDT #{price_usdt}"
        return error_response('Invalid product price')
      end

      # Convert price to SOL for payment
      price_sol = CurrencyConversionService.usd_to_sol(price_usdt)

      # Build user data from input
      user_data = build_user_data(checkout_input[:user_inputs])

      # Generate order number
      # Use first 5 characters of wallet address as identifier
      wallet_identifier = user.wallet_address&.first(5)
      order_number = OrderService.generate_order_number(
        title: topup_product.title,
        name: wallet_identifier
      )

      # Create order
      # Note: amount field only supports 2 decimals, so we store USDT there
      # crypto_amount field supports 9 decimals for SOL
      order = Order.create!(
        user: user,
        topup_product_item: topup_product_item,
        order_number: order_number,
        order_type: 'topup_product',
        status: 'pending',
        amount: price_usdt,           # Store USDT in amount (2 decimals)
        currency: 'USDT',              # Original currency for amount
        crypto_amount: price_sol,      # Store SOL in crypto_amount (9 decimals)
        crypto_currency: 'SOL',        # Crypto currency
        user_data: user_data,
        metadata: {
          validation_data: validation_data,
          price_myr: price_myr,
          price_usdt: price_usdt,
          price_sol: price_sol,
          checkout_input: checkout_input.to_h
        }.to_json
      )

      # Create audit log
      AuditLog.create!(
        user: user,
        action: 'topup_product_checkout',
        auditable: order,
        metadata: {
          order_number: order_number,
          product_name: topup_product.title,
          item_name: topup_product_item.name,
          price_myr: price_myr,
          price_usdt: price_usdt,
          price_sol: price_sol
        }
      )

      # Return checkout data
      success_response(
        order: order,
        payment_amount: price_sol,
        payment_currency: 'SOL',
        price_usdt: price_usdt,
        price_myr: price_myr
      )

    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Product not found: #{e.message}"
      error_response('Product not found')
    rescue => e
      Rails.logger.error "Checkout error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      error_response("Error processing checkout: #{e.message}")
    end
  end

  private

  # Build user data hash from user inputs array
  def build_user_data(user_inputs)
    return {} unless user_inputs.present?

    user_inputs.each_with_object({}) do |input, hash|
      hash[input[:name]] = input[:value]
    end
  end

  # Success response format
  def success_response(order:, payment_amount:, payment_currency:, price_usdt:, price_myr:)
    {
      success: true,
      checkout_data: {
        order_number: order.order_number,
        order_id: order.id,
        payment_amount: payment_amount,
        payment_currency: payment_currency,
        wallet_to: ENV.fetch('PLATFORM_WALLET_ADDRESS'),  # Platform wallet to receive payment
        price_usdt: price_usdt,
        price_myr: price_myr,
        status: order.status,
        expires_at: 30.minutes.from_now
      }
    }
  end

  # Error response format
  def error_response(message)
    {
      success: false,
      error: message
    }
  end
end
