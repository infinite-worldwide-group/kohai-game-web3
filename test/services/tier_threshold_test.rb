require "test_helper"

# Test that verifies tier thresholds work correctly with any configuration
class TierThresholdTest < ActiveSupport::TestCase
  setup do
    # Get current thresholds from environment
    @thresholds = KohaiRpcService.tier_thresholds
    puts "\n📊 Testing with thresholds:"
    puts "  Elite: #{@thresholds[:elite]}"
    puts "  Grandmaster: #{@thresholds[:grandmaster]}"
    puts "  Legend: #{@thresholds[:legend]}\n"
  end

  # Test that threshold values are correctly loaded
  test "tier thresholds are loaded from environment" do
    assert @thresholds[:elite].present?
    assert @thresholds[:grandmaster].present?
    assert @thresholds[:legend].present?
    
    # Thresholds should be in ascending order
    assert @thresholds[:elite] < @thresholds[:grandmaster]
    assert @thresholds[:grandmaster] < @thresholds[:legend]
  end

  # Test user below elite threshold
  test "user below elite threshold has no tier" do
    below_elite = @thresholds[:elite] - 1
    
    user = User.create!(
      wallet_address: "below_elite_#{SecureRandom.hex(10)}",
      tier: nil,
      kohai_balance: below_elite,
      tier_checked_at: 1.minute.ago
    )
    
    result = TierService.check_tier_status(user)
    assert_equal :none, result[:tier]
    assert_equal 0, result[:discount_percent]
  end

  # Test user at exactly elite threshold
  test "user at exactly elite threshold is elite" do
    user = User.create!(
      wallet_address: "at_elite_#{SecureRandom.hex(10)}",
      tier: :elite,
      kohai_balance: @thresholds[:elite],
      tier_checked_at: 1.minute.ago
    )
    
    result = TierService.check_tier_status(user)
    assert_equal :elite, result[:tier]
    assert_equal 1, result[:discount_percent]
  end

  # Test user between elite and grandmaster
  test "user between elite and grandmaster thresholds is elite" do
    balance = (@thresholds[:elite] + @thresholds[:grandmaster]) / 2
    
    user = User.create!(
      wallet_address: "between_elite_gm_#{SecureRandom.hex(10)}",
      tier: :elite,
      kohai_balance: balance,
      tier_checked_at: 1.minute.ago
    )
    
    result = TierService.check_tier_status(user)
    assert_equal :elite, result[:tier]
    assert_equal 1, result[:discount_percent]
  end

  # Test user at exactly grandmaster threshold
  test "user at exactly grandmaster threshold is grandmaster" do
    user = User.create!(
      wallet_address: "at_grandmaster_#{SecureRandom.hex(10)}",
      tier: :grandmaster,
      kohai_balance: @thresholds[:grandmaster],
      tier_checked_at: 1.minute.ago
    )
    
    result = TierService.check_tier_status(user)
    assert_equal :grandmaster, result[:tier]
    assert_equal 2, result[:discount_percent]
  end

  # Test user between grandmaster and legend
  test "user between grandmaster and legend thresholds is grandmaster" do
    balance = (@thresholds[:grandmaster] + @thresholds[:legend]) / 2
    
    user = User.create!(
      wallet_address: "between_gm_legend_#{SecureRandom.hex(10)}",
      tier: :grandmaster,
      kohai_balance: balance,
      tier_checked_at: 1.minute.ago
    )
    
    result = TierService.check_tier_status(user)
    assert_equal :grandmaster, result[:tier]
    assert_equal 2, result[:discount_percent]
  end

  # Test user at exactly legend threshold
  test "user at exactly legend threshold is legend" do
    user = User.create!(
      wallet_address: "at_legend_#{SecureRandom.hex(10)}",
      tier: :legend,
      kohai_balance: @thresholds[:legend],
      tier_checked_at: 1.minute.ago
    )
    
    result = TierService.check_tier_status(user)
    assert_equal :legend, result[:tier]
    assert_equal 3, result[:discount_percent]
  end

  # Test user way above legend threshold
  test "user way above legend threshold is still legend" do
    above_legend = @thresholds[:legend] * 10
    
    user = User.create!(
      wallet_address: "above_legend_#{SecureRandom.hex(10)}",
      tier: :legend,
      kohai_balance: above_legend,
      tier_checked_at: 1.minute.ago
    )
    
    result = TierService.check_tier_status(user)
    assert_equal :legend, result[:tier]
    assert_equal 3, result[:discount_percent]
  end

  # Test discount calculation with current thresholds
  test "discount calculations are correct for all tiers" do
    topup_product = TopupProduct.create!(
      title: "Test Product",
      code: "test"
    )
    
    product = topup_product.topup_product_items.create!(
      name: "Test Item",
      price: 100.0,
      currency: "MYR"
    )
    
    [
      [nil, 0, 100.0],                              # No tier
      [:elite, 1, 99.0],                            # 1% discount
      [:grandmaster, 2, 98.0],                      # 2% discount
      [:legend, 3, 97.0],                           # 3% discount
    ].each do |tier, expected_discount, expected_price|
      user = User.create!(
        wallet_address: "discount_test_#{tier}_#{SecureRandom.hex(10)}",
        tier: tier,
        kohai_balance: @thresholds[tier] || 0,
        tier_checked_at: 1.minute.ago
      )
      
      discount_info = product.calculate_user_discount(user)
      assert_equal expected_discount, discount_info[:discount_percent], 
        "Tier #{tier} should have #{expected_discount}% discount"
      assert_equal expected_price, discount_info[:discounted_price],
        "Discounted price for tier #{tier} should be #{expected_price}"
    end
  end

  # Test all discount percentages
  test "all discount percentages are correct" do
    tier_discounts = {
      :none => 0,
      :elite => 1,
      :grandmaster => 2,
      :legend => 3
    }
    
    tier_discounts.each do |tier, expected_percent|
      user = User.create!(
        wallet_address: "tier_discount_#{tier}_#{SecureRandom.hex(10)}",
        tier: tier,
        kohai_balance: @thresholds[tier] || 0,
        tier_checked_at: 1.minute.ago
      )
      
      result = TierService.check_tier_status(user)
      assert_equal expected_percent, result[:discount_percent],
        "Tier #{tier} should have #{expected_percent}% discount"
    end
  end

  # Test tier info includes correct style
  test "tier info includes correct style for each tier" do
    styles = {
      :elite => "silver",
      :grandmaster => "gold",
      :legend => "orange"
    }
    
    styles.each do |tier, expected_style|
      user = User.create!(
        wallet_address: "style_test_#{tier}_#{SecureRandom.hex(10)}",
        tier: tier,
        kohai_balance: @thresholds[tier],
        tier_checked_at: 1.minute.ago
      )
      
      result = TierService.check_tier_status(user)
      assert_equal expected_style, result[:style],
        "Tier #{tier} should have style #{expected_style}"
    end
  end
end
