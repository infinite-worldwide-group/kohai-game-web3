# frozen_string_literal: true

require "test_helper"

class TopupProductItemTest < ActiveSupport::TestCase
  setup do
    # Create test product
    @product = TopupProduct.create!(
      title: "Test Game",
      code: "test_game",
      slug: "test-game",
      is_active: true
    )

    # Create test items with custom pricing
    @elite_item = TopupProductItem.create!(
      topup_product: @product,
      name: "500 Credits",
      price: 5000.0,
      currency: "MYR",
      active: true
    )

    @grandmaster_item = TopupProductItem.create!(
      topup_product: @product,
      name: "1000 Credits",
      price: 10000.0,
      currency: "MYR",
      active: true
    )

    @legend_item = TopupProductItem.create!(
      topup_product: @product,
      name: "2000 Credits",
      price: 30000.0,
      currency: "MYR",
      active: true
    )

    # Create test users with different tier levels and cache tier info
    @no_tier_user = create_test_user(4999.0, :none)         # Below Elite
    @elite_user = create_test_user(7500.0, :elite)          # Elite tier (5000-9999)
    @grandmaster_user = create_test_user(20000.0, :grandmaster)  # Grandmaster tier (10000-29999)
    @legend_user = create_test_user(50000.0, :legend)       # Legend tier (30000+)
  end

  # Test tier definitions with custom values
  test "tier constants match requirements" do
    tiers = [
      { name: "Elite", required: 5000, discount: 1, style: "silver" },
      { name: "Grandmaster", required: 10000, discount: 2, style: "gold" },
      { name: "Legend", required: 30000, discount: 3, style: "orange" }
    ]

    assert_equal "Elite", tiers[0][:name]
    assert_equal 5000, tiers[0][:required]
    assert_equal 1, tiers[0][:discount]
    assert_equal "silver", tiers[0][:style]

    assert_equal "Grandmaster", tiers[1][:name]
    assert_equal 10000, tiers[1][:required]
    assert_equal 2, tiers[1][:discount]
    assert_equal "gold", tiers[1][:style]

    assert_equal "Legend", tiers[2][:name]
    assert_equal 30000, tiers[2][:required]
    assert_equal 3, tiers[2][:discount]
    assert_equal "orange", tiers[2][:style]
  end

  # Test calculating discount for no-tier user
  test "no tier user gets 0% discount" do
    discount_info = @elite_item.calculate_user_discount(@no_tier_user)

    assert_equal 5000.0, discount_info[:original_price]
    assert_equal 0, discount_info[:discount_percent]
    assert_equal 0.0, discount_info[:discount_amount]
    assert_equal 5000.0, discount_info[:discounted_price]
  end

  # Test calculating discount for Elite tier user
  test "elite tier user gets 1% discount" do
    discount_info = @elite_item.calculate_user_discount(@elite_user)

    assert_equal 5000.0, discount_info[:original_price]
    assert_equal 1, discount_info[:discount_percent]
    assert_equal 50.0, discount_info[:discount_amount]  # 5000 * 1% = 50
    assert_equal 4950.0, discount_info[:discounted_price]
  end

  # Test calculating discount for Grandmaster tier user
  test "grandmaster tier user gets 2% discount" do
    discount_info = @grandmaster_item.calculate_user_discount(@grandmaster_user)

    assert_equal 10000.0, discount_info[:original_price]
    assert_equal 2, discount_info[:discount_percent]
    assert_equal 200.0, discount_info[:discount_amount]  # 10000 * 2% = 200
    assert_equal 9800.0, discount_info[:discounted_price]
  end

  # Test calculating discount for Legend tier user
  test "legend tier user gets 3% discount" do
    discount_info = @legend_item.calculate_user_discount(@legend_user)

    assert_equal 30000.0, discount_info[:original_price]
    assert_equal 3, discount_info[:discount_percent]
    assert_equal 900.0, discount_info[:discount_amount]  # 30000 * 3% = 900
    assert_equal 29100.0, discount_info[:discounted_price]
  end

  # Test user at boundary (exactly 5000) is Elite
  test "user with exactly 5000 is Elite tier" do
    boundary_user = create_test_user(5000.0, :elite)
    discount_info = @elite_item.calculate_user_discount(boundary_user)

    assert_equal 1, discount_info[:discount_percent]
  end

  # Test that user just below boundary (4999) has no tier
  test "user with 4999 has no tier" do
    boundary_user = create_test_user(4999.0, :none)
    discount_info = @elite_item.calculate_user_discount(boundary_user)

    assert_equal 0, discount_info[:discount_percent]
  end

  # Test that user at Grandmaster boundary (exactly 10000) is Grandmaster
  test "user with exactly 10000 is Grandmaster tier" do
    boundary_user = create_test_user(10000.0, :grandmaster)
    discount_info = @grandmaster_item.calculate_user_discount(boundary_user)

    assert_equal 2, discount_info[:discount_percent]
  end

  # Test that user between Elite and Grandmaster gets Elite discount
  test "user with 7500 is Elite tier (not Grandmaster)" do
    boundary_user = create_test_user(7500.0, :elite)
    discount_info = @elite_item.calculate_user_discount(boundary_user)

    assert_equal 1, discount_info[:discount_percent]
  end

  # Test that user at Legend boundary (exactly 30000) is Legend
  test "user with exactly 30000 is Legend tier" do
    boundary_user = create_test_user(30000.0, :legend)
    discount_info = @legend_item.calculate_user_discount(boundary_user)

    assert_equal 3, discount_info[:discount_percent]
  end

  # Test discount calculations on different price points for Elite
  test "elite discount on various prices" do
    prices = [1000, 5000, 10000, 50000]
    expected_discounts = [10, 50, 100, 500]

    prices.each_with_index do |price, index|
      item = TopupProductItem.create!(
        topup_product: @product,
        name: "Item #{price}",
        price: price.to_f,
        currency: "MYR",
        active: true
      )

      discount_info = item.calculate_user_discount(@elite_user)
      assert_equal expected_discounts[index].to_f, discount_info[:discount_amount],
                   "Failed for price #{price}"
    end
  end

  # Test discount calculations for Grandmaster
  test "grandmaster discount on various prices" do
    prices = [1000, 5000, 10000, 50000]
    expected_discounts = [20, 100, 200, 1000]

    prices.each_with_index do |price, index|
      item = TopupProductItem.create!(
        topup_product: @product,
        name: "Item #{price}",
        price: price.to_f,
        currency: "MYR",
        active: true
      )

      discount_info = item.calculate_user_discount(@grandmaster_user)
      assert_equal expected_discounts[index].to_f, discount_info[:discount_amount],
                   "Failed for price #{price}"
    end
  end

  # Test discount calculations for Legend
  test "legend discount on various prices" do
    prices = [1000, 5000, 10000, 30000, 50000]
    expected_discounts = [30, 150, 300, 900, 1500]

    prices.each_with_index do |price, index|
      item = TopupProductItem.create!(
        topup_product: @product,
        name: "Item #{price}",
        price: price.to_f,
        currency: "MYR",
        active: true
      )

      discount_info = item.calculate_user_discount(@legend_user)
      assert_equal expected_discounts[index].to_f, discount_info[:discount_amount],
                   "Failed for price #{price}"
    end
  end

  # Test tier_info is included in discount calculation
  test "discount_info includes tier_info for logged in user" do
    discount_info = @legend_item.calculate_user_discount(@legend_user)

    assert_not_nil discount_info[:tier_info]
    assert_equal :legend, discount_info[:tier_info][:tier]
    assert_equal 3, discount_info[:tier_info][:discount_percent]
  end

  # Test tier_info is nil for nil user
  test "discount_info has nil tier_info for nil user" do
    discount_info = @elite_item.calculate_user_discount(nil)

    assert_nil discount_info[:tier_info]
  end

  # Test formatted_price shows currency
  test "formatted_price includes currency" do
    assert_equal "5000.0 MYR", @elite_item.formatted_price
    assert_equal "10000.0 MYR", @grandmaster_item.formatted_price
    assert_equal "30000.0 MYR", @legend_item.formatted_price
  end

  # Test display_name fallback
  test "display_name uses name if present" do
    assert_equal "500 Credits", @elite_item.display_name
  end

  test "display_name uses ID if name is blank" do
    item = TopupProductItem.create!(
      topup_product: @product,
      name: "",
      price: 1000.0,
      currency: "MYR",
      active: true
    )

    assert_equal "Item ##{item.id}", item.display_name
  end

  private

  def create_test_user(kohai_balance, tier = :none)
    user = User.create!(
      email: "test#{SecureRandom.hex(4)}@example.com",
      wallet_address: "test#{SecureRandom.hex(4)}",
      kohai_balance: kohai_balance
    )
    
    # Cache tier info for testing (avoids blockchain calls)
    tier_name = tier == :none ? nil : tier.to_s.titleize
    user.update_columns(
      tier: tier == :none ? nil : tier.to_s,
      tier_checked_at: Time.current
    )
    
    user
  end
end
