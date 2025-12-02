require 'net/http'
require 'uri'
require 'json'

module SolanaApi
  extend self

  # Get transaction signatures for a wallet address
  def get_signatures_for_address(wallet_address, limit = 10)
    body = {
      jsonrpc: "2.0",
      id: 1,
      method: "getSignaturesForAddress",
      params: [
        wallet_address,
        { limit: limit }
      ]
    }

    post(rpc_url, "", body)
  end

  # Check the status of transaction signatures
  def get_signature_statuses(signatures, search_history: true)
    body = {
      jsonrpc: "2.0",
      id: 1,
      method: "getSignatureStatuses",
      params: [
        signatures.is_a?(Array) ? signatures : [signatures],
        { searchTransactionHistory: search_history }
      ]
    }

    post(rpc_url, "", body)
  end

  # Get detailed transaction information
  def get_transaction(signature)
    body = {
      jsonrpc: "2.0",
      id: 1,
      method: "getTransaction",
      params: [
        signature,
        { encoding: "json", maxSupportedTransactionVersion: 0 }
      ]
    }

    post(rpc_url, "", body)
  end



  private

  def rpc_url
    ENV.fetch("SOLANA_RPC_URL", "https://api.devnet.solana.com")
  end

  def get(url, path, body)
    send_request_get(url, path, body)
  end
  
  def post(url, path, body)
    send_request_post(url, path, body)
  end

    def send_request_get(url, path, body = nil)
    merge_url = url + path
    uri = URI("#{merge_url}")

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)

    request['Content-Type'] = 'application/json'
    request.body = JSON.dump(body)

    response = https.request(request)

    case response.code
    when '401'
      raise "Unauthorized: #{response.code} - #{response.message}"
    when '404'
      raise "Not Found: #{response.code} - #{response.message}"
    when '500'
      raise "Internal Server Error: #{response.code} - #{response.message}"
    else
      JSON.parse(response.body)
    end
  end
  
  def send_request_post(url, path, body = nil)
    merge_url = url + path
    uri = URI("#{merge_url}")

    puts "POST request to: #{merge_url} with body: #{body}"  # Debugging information

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)
    request['Content-Type'] = 'application/json'
    request.body = JSON.dump(body)

    response = https.request(request)
  
    case response.code
    when '401'
      raise "Unauthorized: #{response.code} - #{response.message}"
    when '404'
      raise "Not Found: #{response.code} - #{response.message}"
    when '500'
      raise "Internal Server Error: #{response.code} - #{response.message}"
    else
      JSON.parse(response.body)
    end
  end

  def send_request_post_inquiry(url, path, body = nil)

    merge_url = url + path
    uri = URI("#{merge_url}")

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)

    request['Content-Type'] = 'application/json'
    request.body = JSON.dump(body)
    https.request(request)

    response = Net::HTTP.start(uri.hostname, :use_ssl => uri.scheme == 'https') do |http|
      http.request(request)
    end

    case response.code
    when '401'
      raise "Unauthorized: #{response.code} - #{response.message}"
    when '404'
      raise "Not Found: #{response.code} - #{response.message}"
    when '500'
      raise "Internal Server Error: #{response.code} - #{response.message}"
    else
      JSON.parse(response.body)
    end
  end
end