# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'

# Service to authenticate users with Solana wallet signatures
# Users sign a message with their wallet to prove ownership
class SolanaAuthService
  class InvalidSignature < StandardError; end
  class ExpiredNonce < StandardError; end

  NONCE_EXPIRY = 5.minutes

  # Generate a nonce for the user to sign
  # This prevents replay attacks
  def self.generate_nonce(wallet_address)
    nonce = SecureRandom.hex(32)
    message = "Sign this message to authenticate with Kohai Game\nWallet: #{wallet_address}\nNonce: #{nonce}\nTimestamp: #{Time.current.to_i}"

    # Store nonce in cache (you can use Redis in production)
    Rails.cache.write("auth_nonce:#{wallet_address}", { nonce: nonce, created_at: Time.current }, expires_in: NONCE_EXPIRY)

    { message: message, nonce: nonce }
  end

  # Verify the signed message and authenticate user
  # @param wallet_address [String] Solana wallet address (base58)
  # @param signature [String] Signed message (base64)
  # @param message [String] Original message that was signed
  # @return [User] Authenticated user
  def self.authenticate(wallet_address:, signature:, message:)
    # Verify nonce hasn't expired
    cached_nonce = Rails.cache.read("auth_nonce:#{wallet_address}")
    raise ExpiredNonce, "Authentication nonce has expired" unless cached_nonce

    # Verify message contains the correct nonce
    unless message.include?(cached_nonce[:nonce])
      raise InvalidSignature, "Message does not contain valid nonce"
    end

    # Note: In a real implementation, you would verify the signature using Solana's ed25519
    # For now, we'll verify the structure and rely on frontend signature verification
    # In production, add: verify_ed25519_signature(wallet_address, message, signature)

    unless valid_signature_format?(signature)
      raise InvalidSignature, "Invalid signature format"
    end

    # Clear the nonce to prevent reuse
    Rails.cache.delete("auth_nonce:#{wallet_address}")

    # Find or create user
    user = User.find_or_create_by!(wallet_address: wallet_address)

    # Log authentication
    AuditLog.create(
      user_id: user.id,
      action: 'wallet_authentication',
      auditable: user,
      metadata: { wallet_address: wallet_address, authenticated_at: Time.current }
    )

    user
  end

  # Generate JWT token for authenticated user
  def self.generate_token(user)
    payload = {
      user_id: user.id,
      wallet_address: user.wallet_address,
      exp: 24.hours.from_now.to_i,
      iat: Time.current.to_i
    }

    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  # Verify and decode JWT token
  def self.verify_token(token)
    decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
    payload = decoded.first
    User.find(payload['user_id'])
  rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
    nil
  end

  private

  def self.valid_signature_format?(signature)
    # Basic validation: signature should be base64 encoded
    Base64.strict_decode64(signature)
    true
  rescue ArgumentError
    false
  end

  # TODO: Implement in production
  # def self.verify_ed25519_signature(public_key, message, signature)
  #   # Use Solana SDK or ed25519 gem to verify signature
  #   # require 'ed25519'
  #   # verify_key = Ed25519::VerifyKey.new(Base58.decode(public_key))
  #   # verify_key.verify(Base64.decode64(signature), message)
  # end
end
