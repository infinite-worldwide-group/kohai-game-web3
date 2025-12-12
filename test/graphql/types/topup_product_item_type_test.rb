# frozen_string_literal: true

require "test_helper"

class TopupProductItemTypeTest < ActiveSupport::TestCase
  setup do
    # Create test product
    @product = TopupProduct.create!(
      title: "Test Game",
      code: "test_game",
      slug: "test-game",
      is_active: true
    )

    # Create test items
    @item = TopupProductItem.create!(
      topup_product: @product,
      name: "500 Credits",
      price: 5000.0,
      currency: "MYR",
      active: true
    )

    # Create test users
    @no_tier_user = User.create!(
      email: "no_tier@example.com",
      wallet_address: "wallet_no_tier",
      kohai_balance: 1000.0
    )

    @elite_user = User.create!(
      email: "elite@example.com",
      wallet_address: "wallet_elite",
      kohai_balance: 5000.0
    )

    @legend_user = User.create!(
      email: "legend@example.com",
      wallet_address: "wallet_legend",
      kohai_balance: 50000.0
    )
  end

  # Test that GraphQL type fields exist and can be accessed
  test "topup_product_item_type has all required fields" do
    type = Types::TopupProductItemType
    
    fields = type.fields.keys
    
    assert_includes fields, "id"
    assert_includes fields, "name"
    assert_includes fields, "price"
    assert_includes fields, "currency"
    assert_includes fields, "discountPercent"
    assert_includes fields, "discountAmount"
    assert_includes fields, "discountedPrice"
    assert_includes fields, "discountedPriceUsdt"
    assert_includes fields, "tierInfo"
  end

  # Test GraphQL resolver with Elite user context
  test "graphql resolver calculates elite discount" do
    context = { current_user: @elite_user }
    type_instance = Types::TopupProductItemType.new(@item, context)

    assert_equal 1, type_instance.discount_percent
    assert_equal 50.0, type_instance.discount_amount
    assert_equal 4950.0, type_instance.discounted_price
  end

  # Test GraphQL resolver with Legend user context
  test "graphql resolver calculates legend discount" do
    context = { current_user: @legend_user }
    type_instance = Types::TopupProductItemType.new(@item, context)

    assert_equal 3, type_instance.discount_percent
    assert_equal 150.0, type_instance.discount_amount
    assert_equal 4850.0, type_instance.discounted_price
  end

  # Test GraphQL resolver with no tier user
  test "graphql resolver returns zero discount for non-tier user" do
    context = { current_user: @no_tier_user }
    type_instance = Types::TopupProductItemType.new(@item, context)

    assert_equal 0, type_instance.discount_percent
    assert_equal 0.0, type_instance.discount_amount
    assert_equal 5000.0, type_instance.discounted_price
  end

  # Test GraphQL resolver without user context
  test "graphql resolver returns zero discount when no current_user" do
    context = { current_user: nil }
    type_instance = Types::TopupProductItemType.new(@item, context)

    assert_equal 0, type_instance.discount_percent
    assert_equal 0.0, type_instance.discount_amount
    assert_equal 5000.0, type_instance.discounted_price
  end

  # Test tier_info resolver
  test "tier_info resolver returns user tier information" do
    context = { current_user: @legend_user }
    type_instance = Types::TopupProductItemType.new(@item, context)
    
    tier_info = type_instance.tier_info
    
    assert_not_nil tier_info
    assert tier_info.is_a?(Hash)
    assert_equal :legend, tier_info[:tier]
    assert_equal 3, tier_info[:discount_percent]
  end

  # Test tier_info resolver returns nil for nil user
  test "tier_info resolver returns nil when no current_user" do
    context = { current_user: nil }
    type_instance = Types::TopupProductItemType.new(@item, context)
    
    assert_nil type_instance.tier_info
  end

  # Test display_name resolver
  test "display_name resolver returns item name" do
    context = { current_user: @elite_user }
    type_instance = Types::TopupProductItemType.new(@item, context)

    assert_equal "500 Credits", type_instance.display_name
  end

  # Test formatted_price resolver
  test "formatted_price resolver includes currency" do
    context = { current_user: @elite_user }
    type_instance = Types::TopupProductItemType.new(@item, context)

    assert_equal "5000.0 MYR", type_instance.formatted_price
  end

  # Test currency resolver
  test "currency resolver returns correct currency" do
    context = { current_user: @elite_user }
    type_instance = Types::TopupProductItemType.new(@item, context)

    assert_equal "MYR", type_instance.currency
  end

  # Test discounted_price_usdt calculation
  test "discounted_price_usdt returns proper USDT value" do
    context = { current_user: @elite_user }
    type_instance = Types::TopupProductItemType.new(@item, context)

    # Should be the discounted price (4950) converted to USDT
    discounted_usdt = type_instance.discounted_price_usdt
    
    # Just verify it returns a positive number
    assert discounted_usdt > 0
    assert discounted_usdt.is_a?(Float)
  end
end
