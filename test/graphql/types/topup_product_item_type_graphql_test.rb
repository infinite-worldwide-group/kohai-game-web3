# frozen_string_literal: true

require "test_helper"

class TopupProductItemTypeGraphQLTest < ActiveSupport::TestCase
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
      kohai_balance: 5000.0,
      tier: "elite",
      tier_checked_at: Time.current
    )

    @legend_user = User.create!(
      email: "legend@example.com",
      wallet_address: "wallet_legend",
      kohai_balance: 50000.0,
      tier: "legend",
      tier_checked_at: Time.current
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

  # Test that topup products query returns discount fields
  test "topup_product query returns discount fields for elite user" do
    query = <<~GRAPHQL
      query GetProduct($id: ID!) {
        topupProduct(id: $id) {
          id
          title
          topupProductItems {
            id
            name
            price
            currency
            discountPercent
            discountAmount
            discountedPrice
            tierInfo
          }
        }
      }
    GRAPHQL

    variables = { id: @product.id.to_s }
    context = { current_user: @elite_user }
    
    result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)

    assert_nil result["errors"], "Query should not have errors"
    
    product = result["data"]["topupProduct"]
    assert_equal "Test Game", product["title"]
    
    items = product["topupProductItems"]
    assert_not_empty items
    
    item = items[0]
    assert_equal 1, item["discountPercent"]
    assert_equal 50.0, item["discountAmount"]
    assert_equal 4950.0, item["discountedPrice"]
    
    tier_info = item["tierInfo"]
    assert_equal "elite", tier_info["tier"]
  end

  # Test legend user gets 3% discount
  test "topup_product query returns 3% discount for legend user" do
    query = <<~GRAPHQL
      query GetProduct($id: ID!) {
        topupProduct(id: $id) {
          topupProductItems {
            id
            name
            price
            discountPercent
            discountAmount
            discountedPrice
            tierInfo
          }
        }
      }
    GRAPHQL

    variables = { id: @product.id.to_s }
    context = { current_user: @legend_user }
    
    result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)

    assert_nil result["errors"]
    
    items = result["data"]["topupProduct"]["topupProductItems"]
    item = items[0]
    
    assert_equal 3, item["discountPercent"]
    assert_equal 150.0, item["discountAmount"]
    assert_equal 4850.0, item["discountedPrice"]
    
    tier_info = item["tierInfo"]
    assert_equal "legend", tier_info["tier"]
  end

  # Test no tier user gets 0% discount
  test "topup_product query returns no discount for non-tier user" do
    query = <<~GRAPHQL
      query GetProduct($id: ID!) {
        topupProduct(id: $id) {
          topupProductItems {
            id
            name
            price
            discountPercent
            discountAmount
            discountedPrice
          }
        }
      }
    GRAPHQL

    variables = { id: @product.id.to_s }
    context = { current_user: @no_tier_user }
    
    result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)

    assert_nil result["errors"]
    
    items = result["data"]["topupProduct"]["topupProductItems"]
    item = items[0]
    
    assert_equal 0, item["discountPercent"]
    assert_equal 0.0, item["discountAmount"]
    assert_equal 5000.0, item["discountedPrice"]
  end

  # Test unauthenticated user gets 0% discount
  test "topup_product query returns no discount when unauthenticated" do
    query = <<~GRAPHQL
      query GetProduct($id: ID!) {
        topupProduct(id: $id) {
          topupProductItems {
            id
            name
            price
            discountPercent
            discountAmount
            discountedPrice
          }
        }
      }
    GRAPHQL

    variables = { id: @product.id.to_s }
    context = { current_user: nil }
    
    result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)

    assert_nil result["errors"]
    
    items = result["data"]["topupProduct"]["topupProductItems"]
    item = items[0]
    
    assert_equal 0, item["discountPercent"]
    assert_equal 0.0, item["discountAmount"]
  end

  # Test different discount amounts for different tier levels on same item
  test "same item shows different discounts for different user tiers" do
    query = <<~GRAPHQL
      query GetProduct($id: ID!) {
        topupProduct(id: $id) {
          topupProductItems {
            id
            name
            price
            discountPercent
            discountAmount
            discountedPrice
          }
        }
      }
    GRAPHQL

    variables = { id: @product.id.to_s }
    
    # Test with Elite user
    context = { current_user: @elite_user }
    elite_result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)
    elite_discount = elite_result["data"]["topupProduct"]["topupProductItems"][0]["discountPercent"]

    # Test with Legend user
    context = { current_user: @legend_user }
    legend_result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)
    legend_discount = legend_result["data"]["topupProduct"]["topupProductItems"][0]["discountPercent"]

    # Test with Non-tier user
    context = { current_user: @no_tier_user }
    no_tier_result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)
    no_tier_discount = no_tier_result["data"]["topupProduct"]["topupProductItems"][0]["discountPercent"]

    # Verify discounts
    assert_equal 1, elite_discount
    assert_equal 3, legend_discount
    assert_equal 0, no_tier_discount
  end
end
