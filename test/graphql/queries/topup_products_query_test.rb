# frozen_string_literal: true

require "test_helper"

class TopupProductsQueryTest < ActiveSupport::TestCase
  setup do
    # Create test product
    @product = TopupProduct.create!(
      title: "Mobile Legends",
      code: "mlbb",
      slug: "mobile-legends",
      category: "games",
      is_active: true
    )

    # Create items with tier boundaries
    @elite_boundary_item = TopupProductItem.create!(
      topup_product: @product,
      name: "Elite Item",
      price: 5000.0,
      currency: "MYR",
      active: true
    )

    @grandmaster_item = TopupProductItem.create!(
      topup_product: @product,
      name: "Grandmaster Item",
      price: 10000.0,
      currency: "MYR",
      active: true
    )

    @legend_item = TopupProductItem.create!(
      topup_product: @product,
      name: "Legend Item",
      price: 30000.0,
      currency: "MYR",
      active: true
    )

    # Create test users
    @no_tier_user = User.create!(
      email: "no_tier@example.com",
      wallet_address: "wallet_no_tier",
      kohai_balance: 100.0
    )

    @elite_user = User.create!(
      email: "elite@example.com",
      wallet_address: "wallet_elite",
      kohai_balance: 5000.0,
      tier: "elite",
      tier_checked_at: Time.current
    )

    @grandmaster_user = User.create!(
      email: "grandmaster@example.com",
      wallet_address: "wallet_grandmaster",
      kohai_balance: 15000.0,
      tier: "grandmaster",
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

  # Test topup products query returns items with discount fields
  test "topup_products query returns discounted pricing for elite user" do
    query = <<~GRAPHQL
      {
        topupProducts {
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

    context = { current_user: @elite_user }
    result = KohaiGameWeb3Schema.execute(query, context: context)

    assert_nil result["errors"], "Query should not have errors"
    
    products = result["data"]["topupProducts"]
    assert_not_empty products
    
    # Find the mobile legends product
    mobile_legends = products.find { |p| p["title"] == "Mobile Legends" }
    assert mobile_legends
    
    items = mobile_legends["topupProductItems"]
    assert_not_empty items
    
    # Check elite boundary item has 1% discount
    elite_item = items.find { |item| item["name"] == "Elite Item" }
    assert_equal 1, elite_item["discountPercent"]
    assert_equal 50.0, elite_item["discountAmount"]
    assert_equal 4950.0, elite_item["discountedPrice"]
    assert_equal "elite", elite_item["tierInfo"]["tier"]
  end

  # Test topup products query for legend user
  test "topup_products query returns discounted pricing for legend user" do
    query = <<~GRAPHQL
      {
        topupProducts {
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

    context = { current_user: @legend_user }
    result = KohaiGameWeb3Schema.execute(query, context: context)

    assert_nil result["errors"]
    
    products = result["data"]["topupProducts"]
    mobile_legends = products.find { |p| p["title"] == "Mobile Legends" }
    
    items = mobile_legends["topupProductItems"]
    
    # Check legend item has 3% discount
    legend_item = items.find { |item| item["name"] == "Legend Item" }
    assert_equal 3, legend_item["discountPercent"]
    assert_equal 900.0, legend_item["discountAmount"]
    assert_equal 29100.0, legend_item["discountedPrice"]
    assert_equal "legend", legend_item["tierInfo"]["tier"]
  end

  # Test topup products query for non-tier user
  test "topup_products query returns no discount for non-tier user" do
    query = <<~GRAPHQL
      {
        topupProducts {
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
          }
        }
      }
    GRAPHQL

    context = { current_user: @no_tier_user }
    result = KohaiGameWeb3Schema.execute(query, context: context)

    assert_nil result["errors"]
    
    products = result["data"]["topupProducts"]
    mobile_legends = products.find { |p| p["title"] == "Mobile Legends" }
    
    items = mobile_legends["topupProductItems"]
    
    # All items should have 0% discount
    items.each do |item|
      assert_equal 0, item["discountPercent"]
      assert_equal 0.0, item["discountAmount"]
      assert_equal item["price"], item["discountedPrice"]
    end
  end

  # Test topup products query without user context
  test "topup_products query returns no discount when unauthenticated" do
    query = <<~GRAPHQL
      {
        topupProducts {
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
          }
        }
      }
    GRAPHQL

    context = { current_user: nil }
    result = KohaiGameWeb3Schema.execute(query, context: context)

    assert_nil result["errors"]
    
    products = result["data"]["topupProducts"]
    mobile_legends = products.find { |p| p["title"] == "Mobile Legends" }
    
    items = mobile_legends["topupProductItems"]
    
    # All items should have 0% discount
    items.each do |item|
      assert_equal 0, item["discountPercent"]
      assert_equal 0.0, item["discountAmount"]
    end
  end

  # Test single product query with discount info
  test "topup_product query by id includes discount info" do
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
    context = { current_user: @legend_user }
    
    result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)

    assert_nil result["errors"]
    
    product = result["data"]["topupProduct"]
    assert_equal "Mobile Legends", product["title"]
    
    items = product["topupProductItems"]
    legend_item = items.find { |item| item["name"] == "Legend Item" }
    
    assert_equal 3, legend_item["discountPercent"]
    assert_equal "legend", legend_item["tierInfo"]["tier"]
    assert_equal "Legend", legend_item["tierInfo"]["tierName"]
    assert_equal "orange", legend_item["tierInfo"]["style"]
  end

  # Test single product query by slug
  test "topup_product query by slug includes discount info" do
    query = <<~GRAPHQL
      query GetProduct($slug: String!) {
        topupProduct(slug: $slug) {
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
          }
        }
      }
    GRAPHQL

    variables = { slug: @product.slug }
    context = { current_user: @elite_user }
    
    result = KohaiGameWeb3Schema.execute(query, variables: variables, context: context)

    assert_nil result["errors"]
    
    product = result["data"]["topupProduct"]
    assert_equal "Mobile Legends", product["title"]
    
    items = product["topupProductItems"]
    assert_not_empty items
    
    # All items should have 1% elite discount
    items.each do |item|
      assert_equal 1, item["discountPercent"]
    end
  end

  # Test different discount amounts for different tier levels on same item
  test "same item shows different discounts for different user tiers" do
    query = <<~GRAPHQL
      {
        topupProducts {
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

    # Test with Elite user
    context = { current_user: @elite_user }
    elite_result = KohaiGameWeb3Schema.execute(query, context: context)
    elite_items = elite_result["data"]["topupProducts"][0]["topupProductItems"]
    elite_discount = elite_items[0]["discountPercent"]

    # Test with Grandmaster user
    context = { current_user: @grandmaster_user }
    gm_result = KohaiGameWeb3Schema.execute(query, context: context)
    gm_items = gm_result["data"]["topupProducts"][0]["topupProductItems"]
    gm_discount = gm_items[0]["discountPercent"]

    # Test with Legend user
    context = { current_user: @legend_user }
    legend_result = KohaiGameWeb3Schema.execute(query, context: context)
    legend_items = legend_result["data"]["topupProducts"][0]["topupProductItems"]
    legend_discount = legend_items[0]["discountPercent"]

    # Verify discounts increase with tier
    assert_equal 1, elite_discount
    assert_equal 2, gm_discount
    assert_equal 3, legend_discount
  end
end
