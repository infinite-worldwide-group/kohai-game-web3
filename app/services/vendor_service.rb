# frozen_string_literal: true

require 'net/http'
require 'json'
require 'openssl'

module VendorService
  extend self


  def get_balance
    secret_key = ENV['VENDOR_SECRET_KEY'].to_s        # guard against nil
    merchant_id = ENV['VENDOR_MERCHANT_ID'].to_s
    path = '/merchant'                       # or ENV['VENDOR_ENDPOINT_MERCHANT']
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret_key, merchant_id + path)

    body = {
      signature: signature
    }

    get(ENV['VENDOR_URL'], path, body)
  end

  def get_products
    secret_key = ENV['VENDOR_SECRET_KEY'].to_s        # guard against nil
    merchant_id = ENV['VENDOR_MERCHANT_ID'].to_s
    path = '/merchant-products'              # vendor products endpoint
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret_key, merchant_id + path)

    body = {
      signature: signature
    }

    get(ENV['VENDOR_URL'], path, body)
  end

  def get_product(product_id:)
    secret_key = ENV['VENDOR_SECRET_KEY'].to_s
    merchant_id = ENV['VENDOR_MERCHANT_ID'].to_s
    path = "/merchant-products/#{product_id.to_s}"
    payload = merchant_id + path + product_id.to_s
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret_key, payload)

    body = {
      signature: signature
    }

    get(ENV['VENDOR_URL'], path, body)
  end


  def get_product_items(product_id:)
    secret_key = ENV['VENDOR_SECRET_KEY'].to_s
    merchant_id = ENV['VENDOR_MERCHANT_ID'].to_s
    path = "/merchant-products/#{product_id.to_s}/items"
    payload = merchant_id + path + product_id.to_s
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret_key, payload)

    body = {
      signature: signature
    }

    get(ENV['VENDOR_URL'], path, body)
  end
#VendorService.validate_game_account(product_id: '40', user_data: {"User ID"=>"9997766", "insert server value"=>"os_asia"})
  def validate_game_account(product_id:, user_data:)
    secret_key = ENV['VENDOR_SECRET_KEY'].to_s
    merchant_id = ENV['VENDOR_MERCHANT_ID'].to_s
    path = "/validate-game-account"
    payload = merchant_id + path 
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret_key, payload)

    body = {
      signature: signature,
      productId: product_id,
      data: user_data
    }

    post(ENV['VENDOR_URL'], path, body)
  end

  def create_order(product_id:, product_item_id:, user_input:, partner_order_id:, callback_url:)
    secret_key = ENV['VENDOR_SECRET_KEY'].to_s
    merchant_id = ENV['VENDOR_MERCHANT_ID'].to_s
    path = "/merchant-products/#{product_id}/items"
    payload = merchant_id + path + product_id
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret_key, payload)
    topup_product_item = TopupProductItem.find_by(origin_id: product_item_id)
    body = {
      productId: product_id,
      productItemId: product_item_id,
      data: user_input,
      price: topup_product_item&.price,
      reference: partner_order_id,
      callbackUrl: callback_url
    }

    post(ENV['VENDOR_URL'], path, body)
  end

  def check_order_detail(reference_id)
    secret_key = ENV['VENDOR_SECRET_KEY'].to_s
    merchant_id = ENV['VENDOR_MERCHANT_ID'].to_s
    path = "/merchant-order/#{reference_id}"
    payload = merchant_id + path + reference_id
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret_key, payload)

    body = {
      signature: signature,
      api_key: ENV['VENDOR_API_KEY'],
      order_id: reference_id
    }
    post(ENV['VENDOR_URL'], path, body)
  end

  private

  def get(url, path, body)
    send_request_get(url, path, body)
  end
  
  def post(url, path, body)
    send_request_post(url, path, body)
  end

  def send_request_get(url, path, body = nil)
    uri = URI.join(url, path)
    if body.present?
      query = URI.encode_www_form(body)
      uri.query = [uri.query, query].compact.join('&')
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 5
    http.read_timeout = 20
    http.write_timeout = 10 if http.respond_to?(:write_timeout)
    request = Net::HTTP::Get.new(uri.request_uri)
    request['X-Merchant'] = ENV['VENDOR_X_MERCHANT']
    request['Accept'] = 'application/json'

    response = http.request(request)

    code = response.code.to_i
    if code.between?(200, 299)
      begin
        return JSON.parse(response.body)
      rescue JSON::ParserError
        raise "Invalid JSON from provider (#{code})"
      end
    end
    # include vendor response body for easier debugging
    Rails.logger.debug { "VendorService GET #{uri} responded #{response.code}: #{response.body}" } if defined?(Rails)
    raise "HTTP Error: #{response.code} - #{response.message} - #{response.body}"
  end
  
  def send_request_post(url, path, body = nil)
    uri = URI.join(url, path)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 5
    http.read_timeout = 20
    http.write_timeout = 10 if http.respond_to?(:write_timeout)

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    request['X-Merchant'] = ENV['VENDOR_X_MERCHANT']
    request.body = JSON.dump(body)
    response = http.request(request)
  
    code = response.code.to_i
    if code.between?(200, 299)
      begin
        return JSON.parse(response.body)
      rescue JSON::ParserError
        raise "Invalid JSON from provider (#{code})"
      end
    end
    # include vendor response body for easier debugging
    Rails.logger.debug { "VendorService POST #{uri} responded #{response.code}: #{response.body}" } if defined?(Rails)
    raise "HTTP Error: #{response.code} - #{response.message} - #{response.body}"
  end


end