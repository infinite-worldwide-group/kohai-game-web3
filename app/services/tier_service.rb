# frozen_string_literal: true

# Tier Service handles $KOHAI token holder benefits:
# - Tier 1 (50k–499k): Elite → 1% discount (silver)
# - Tier 2 (500k–2.9M): Grandmaster → 2% discount (gold)
# - Tier 3 (3M+): Legend → 3% discount (glowing orange)
module TierService
  extend self

  # Check user's tier status and return discount information
  # Uses cached tier if less than 5 minutes old, otherwise fetches from blockchain
  # @param user [User] The user to check
  # @param force_refresh [Boolean] Force refresh from blockchain (default: false)
  # @return [Hash] Tier information including discount, badge, style, and balance
  def check_tier_status(user, force_refresh: false)
    return default_status unless user&.wallet_address.present?

    # Check if we have a recent cached tier (less than 5 minutes old)
    if !force_refresh && user.tier_checked_at.present? && user.tier_checked_at > 5.minutes.ago
      Rails.logger.info "Using cached tier for user #{user.id} (checked #{time_ago_in_words(user.tier_checked_at)} ago)"

      return {
        tier: user.tier&.to_sym || :none,
        tier_name: user.tier&.titleize,
        discount_percent: discount_for_tier(user.tier),
        referral_percent: discount_for_tier(user.tier),
        badge: user.tier&.titleize,
        style: style_for_tier(user.tier),
        balance: user.kohai_balance || 0.0
      }
    end

    # Cache miss or expired - fetch from blockchain
    Rails.logger.info "Fetching fresh tier from blockchain for user #{user.id}"
    tier_info = KohaiRpcService.get_tier(user.wallet_address)

    # Cache the results on user record
    cache_tier_status(user, tier_info) if user.respond_to?(:tier)

    tier_info
  end

  # Calculate discounted price for an order
  # @param original_price [Float] Original price before discount
  # @param user [User] The user making the purchase
  # @param force_refresh [Boolean] Force refresh from blockchain (default: false)
  # @return [Hash] { original_price:, discount_percent:, discount_amount:, final_price:, tier_info: }
  def calculate_discounted_price(original_price, user, force_refresh: false)
    tier_info = check_tier_status(user, force_refresh: force_refresh)
    discount_percent = tier_info[:discount_percent]

    discount_amount = (original_price * discount_percent / 100.0).round(6)
    final_price = (original_price - discount_amount).round(6)

    {
      original_price: original_price,
      discount_percent: discount_percent,
      discount_amount: discount_amount,
      final_price: final_price,
      tier_info: tier_info
    }
  end

  # Get tier leaderboard (top 100 Legend holders with glowing purple name)
  # @param limit [Integer] Number of top holders to return
  # @return [Array<Hash>] Leaderboard data
  def get_tier_leaderboard(limit = 100)
    # This would need to be cached and updated periodically
    # For now, returning placeholder
    # TODO: Implement caching strategy with periodic blockchain sync
    # Top 100 Legend tier get special purple glow in dapp
    []
  end

  private

  def default_status
    {
      tier: :none,
      tier_name: nil,
      discount_percent: 0,
      referral_percent: 0,
      badge: nil,
      style: nil,
      balance: 0.0
    }
  end

  def cache_tier_status(user, tier_info)
    user.update_columns(
      tier: tier_info[:tier],
      kohai_balance: tier_info[:balance],
      tier_checked_at: Time.current
    )
  rescue => e
    Rails.logger.warn "Failed to cache tier status for user #{user.id}: #{e.message}"
  end

  # Get discount percentage for a tier
  def discount_for_tier(tier)
    case tier&.to_sym
    when :elite then 1
    when :grandmaster then 2
    when :legend then 3
    else 0
    end
  end

  # Get style for a tier
  def style_for_tier(tier)
    case tier&.to_sym
    when :elite then "silver"
    when :grandmaster then "gold"
    when :legend then "orange"
    else nil
    end
  end

  # Helper for time_ago_in_words (Rails helper)
  def time_ago_in_words(time)
    seconds = (Time.current - time).to_i
    return "#{seconds} seconds" if seconds < 60
    minutes = seconds / 60
    return "#{minutes} minutes" if minutes < 60
    hours = minutes / 60
    "#{hours} hours"
  end
end
