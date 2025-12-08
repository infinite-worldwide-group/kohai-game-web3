# frozen_string_literal: true

module OrderService
  extend self

  def generate_order_number(title:, name: nil)
    title_initials = if title.present?
      title.gsub(/\s*\(.*?\)\s*/, '')
           .split
           .map { |word| word[0] }
           .join
           .upcase
    else
      "TOPUP"
    end

    sanitized_name = name.to_s.strip.gsub(/\s+/, '')[0, 5].upcase

    prefix = if name.present?
      "#{sanitized_name}#{title_initials}"
    else
      "KMY#{title_initials}"
    end

    loop do
      random_token = SecureRandom.hex(6).upcase
      order_number = "#{prefix}#{random_token}"
      break order_number unless order_number_exists?(order_number)
    end
  end

  def post_purchase(order:)
    # Validate order has required data
    return fail_order(order, "Missing topup product item") unless order.topup_product_item.present?
    return fail_order(order, "Missing user data") unless order.user_data.present?

    topup_product_item = order.topup_product_item
    topup_product = topup_product_item.topup_product

    # Get product IDs from the topup product item
    product_id = topup_product.origin_id
    product_item_id = topup_product_item.origin_id

    return fail_order(order, "Missing product origin ID") unless product_id.present?
    return fail_order(order, "Missing product item origin ID") unless product_item_id.present?

    # Build callback URL
    callback_url = "https://#{ENV.fetch('DEFAULT_URL')}/api/vendor/callback"

    # Get price in USDT from order (stored in amount field)
    price_usdt = order.amount

    begin
      # Call VendorService to create order
      response = VendorService.create_order(
        product_id: product_id,
        product_item_id: product_item_id,
        user_input: order.user_data,
        partner_order_id: order.order_number,
        callback_url: callback_url,
        price_usdt: price_usdt
      )

      # Check if order was created successfully
      if response['success'] || response['status'] == 'success'
        # Extract invoice/reference ID from response
        invoice_id = response['orderId'] || response['order_id'] || response['invoiceId'] || response['reference']

        if invoice_id.present?
          order.update!(
            invoice_id: invoice_id,
            metadata: response.to_json
          )
          return true
        else
          return fail_order(order, "Missing invoice ID from vendor response")
        end
      else
        error_message = response['message'] || response['error'] || 'Order creation failed'
        return fail_order(order, error_message)
      end

    rescue => e
      Rails.logger.error("VendorService error: #{e.message}")
      return fail_order(order, "Error creating order: #{e.message}")
    end
  end

  def check_order(order)
    return return_respond("invalid", "Please check only processing orders") unless order.processing?
    return return_respond("invalid", "Couldn't find invoice ID") unless order.invoice_id.present?

    begin
      # Call VendorService to check order status
      response = VendorService.check_order_detail(order.invoice_id)

      # Parse the response status
      status = response['status']&.downcase
      message = response['message'] || response['msg'] || ''

      case status
      when 'success', 'completed', 'succeeded'
        order.success!
        return_respond("succeeded", "Order completed successfully")
      when 'failed', 'error'
        order.update(error_message: message)
        order.fail!
        return_respond("failed", message)
      when 'processing', 'pending'
        return_respond("processing", "Order is still being processed")
      else
        return_respond("unknown", "Unknown status: #{status}")
      end

    rescue => e
      Rails.logger.error("VendorService check error: #{e.message}")
      return_respond("error", "Error checking order: #{e.message}")
    end
  end

  private

  def order_number_exists?(order_number)
    Order.exists?(order_number: order_number)
  end

  def fail_order(order, message)
    Rails.logger.error("Order #{order.order_number} failed: #{message}")
    order.update(error_message: message)
    order.fail!
    false
  end

  def return_respond(status, message)
    {
      status: status,
      message: message
    }
  end
end
