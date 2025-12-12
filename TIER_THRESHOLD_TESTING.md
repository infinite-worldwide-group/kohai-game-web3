# Testing with Configurable KOHAI Tier Thresholds

## Overview

The tier threshold values are now **fully configurable** via environment variables, making it easy to test different tier configurations without code changes.

### Default Thresholds
- **Elite**: 50,000 KOHAI
- **Grandmaster**: 500,000 KOHAI
- **Legend**: 3,000,000 KOHAI

---

## Quick Start: Setting Custom Thresholds

### Method 1: Environment Variables (Recommended for Testing)

Set environment variables before running tests:

```bash
# Test with custom tiers (Elite: 5k, Grandmaster: 10k, Legend: 30k)
export KOHAI_ELITE_MIN=5000
export KOHAI_GRANDMASTER_MIN=10000
export KOHAI_LEGEND_MIN=30000

# Now run your tests
bundle exec rails test test/models/topup_product_item_test.rb
```

### Method 2: Inline Environment Setup (In Test Files)

```ruby
# In your test setup
ENV['KOHAI_ELITE_MIN'] = '5000'
ENV['KOHAI_GRANDMASTER_MIN'] = '10000'
ENV['KOHAI_LEGEND_MIN'] = '30000'

# Then require the service (or reload it)
require_relative '../../app/services/kohai_rpc_service'
```

### Method 3: .env File (For Local Development)

Create or update `.env`:

```bash
# .env
KOHAI_ELITE_MIN=5000
KOHAI_GRANDMASTER_MIN=10000
KOHAI_LEGEND_MIN=30000
```

Then load with dotenv gem:
```ruby
# In Rakefile or config/initializers
Dotenv.load if defined?(Dotenv)
```

---

## Example Test Scenarios

### Scenario 1: Low Tier Thresholds (Quick Testing)

```bash
# Set very low thresholds for easy testing
export KOHAI_ELITE_MIN=100
export KOHAI_GRANDMASTER_MIN=200
export KOHAI_LEGEND_MIN=300

bundle exec rails test test/models/topup_product_item_test.rb
```

**Expected Results:**
- User with 150 KOHAI → Elite tier
- User with 250 KOHAI → Grandmaster tier
- User with 350 KOHAI → Legend tier

### Scenario 2: High Tier Thresholds (Production-like)

```bash
# Set high thresholds matching production
export KOHAI_ELITE_MIN=50000
export KOHAI_GRANDMASTER_MIN=500000
export KOHAI_LEGEND_MIN=3000000

bundle exec rails test
```

### Scenario 3: Custom Business Logic Testing

```bash
# Test a new tier strategy
export KOHAI_ELITE_MIN=1000
export KOHAI_GRANDMASTER_MIN=5000
export KOHAI_LEGEND_MIN=10000

bundle exec rails test test/graphql/queries/topup_products_query_test.rb
```

---

## Getting Current Thresholds

### In Your Application Code

```ruby
thresholds = KohaiRpcService.tier_thresholds
# => { elite: 5000.0, grandmaster: 10000.0, legend: 30000.0 }

puts "Elite threshold: #{thresholds[:elite]}"
puts "Grandmaster threshold: #{thresholds[:grandmaster]}"
puts "Legend threshold: #{thresholds[:legend]}"
```

### In Rails Console

```bash
rails console
> KohaiRpcService.tier_thresholds
=> {:elite=>5000.0, :grandmaster=>10000.0, :legend=>30000.0}
```

### In Tests

```ruby
def test_tiers_with_custom_thresholds
  thresholds = KohaiRpcService.tier_thresholds
  
  user_elite = create_test_user(thresholds[:elite])
  assert_equal :elite, TierService.check_tier_status(user_elite)[:tier]
  
  user_grandmaster = create_test_user(thresholds[:grandmaster])
  assert_equal :grandmaster, TierService.check_tier_status(user_grandmaster)[:tier]
end
```

---

## Complete Test Script Example

Create `test_custom_thresholds.sh`:

```bash
#!/bin/bash

echo "🧪 Testing KOHAI Tier Thresholds"
echo "=================================="

# Test 1: Low thresholds
echo ""
echo "Test 1: Low Thresholds (100, 200, 300)"
export KOHAI_ELITE_MIN=100
export KOHAI_GRANDMASTER_MIN=200
export KOHAI_LEGEND_MIN=300

bundle exec rails test test/models/topup_product_item_test.rb -v
if [ $? -eq 0 ]; then
  echo "✅ Low threshold tests PASSED"
else
  echo "❌ Low threshold tests FAILED"
  exit 1
fi

# Test 2: Medium thresholds
echo ""
echo "Test 2: Medium Thresholds (5000, 10000, 30000)"
export KOHAI_ELITE_MIN=5000
export KOHAI_GRANDMASTER_MIN=10000
export KOHAI_LEGEND_MIN=30000

bundle exec rails test test/models/topup_product_item_test.rb -v
if [ $? -eq 0 ]; then
  echo "✅ Medium threshold tests PASSED"
else
  echo "❌ Medium threshold tests FAILED"
  exit 1
fi

# Test 3: Default (production) thresholds
echo ""
echo "Test 3: Default Thresholds (50000, 500000, 3000000)"
export KOHAI_ELITE_MIN=50000
export KOHAI_GRANDMASTER_MIN=500000
export KOHAI_LEGEND_MIN=3000000

bundle exec rails test test/models/topup_product_item_test.rb -v
if [ $? -eq 0 ]; then
  echo "✅ Default threshold tests PASSED"
else
  echo "❌ Default threshold tests FAILED"
  exit 1
fi

echo ""
echo "✅ All threshold tests completed!"
```

Make it executable and run:

```bash
chmod +x test_custom_thresholds.sh
./test_custom_thresholds.sh
```

---

## Writing Tests for Custom Thresholds

### Test Pattern 1: Dynamic Threshold Testing

```ruby
class TierServiceCustomThresholdTest < ActiveSupport::TestCase
  setup do
    # Store original thresholds
    @original_thresholds = KohaiRpcService.tier_thresholds
  end

  test "users are assigned correct tier for current thresholds" do
    # Get current thresholds from environment
    thresholds = KohaiRpcService.tier_thresholds
    
    # Test Elite tier
    elite_user = User.create!(
      wallet_address: "elite_wallet_123",
      tier: :elite,
      kohai_balance: thresholds[:elite],
      tier_checked_at: 1.minute.ago
    )
    assert_equal :elite, TierService.check_tier_status(elite_user)[:tier]
    
    # Test Grandmaster tier
    grandmaster_user = User.create!(
      wallet_address: "grandmaster_wallet_123",
      tier: :grandmaster,
      kohai_balance: thresholds[:grandmaster],
      tier_checked_at: 1.minute.ago
    )
    assert_equal :grandmaster, TierService.check_tier_status(grandmaster_user)[:tier]
    
    # Test Legend tier
    legend_user = User.create!(
      wallet_address: "legend_wallet_123",
      tier: :legend,
      kohai_balance: thresholds[:legend],
      tier_checked_at: 1.minute.ago
    )
    assert_equal :legend, TierService.check_tier_status(legend_user)[:tier]
  end

  test "users below elite threshold have no tier" do
    thresholds = KohaiRpcService.tier_thresholds
    below_threshold = thresholds[:elite] - 1
    
    user = User.create!(
      wallet_address: "no_tier_wallet",
      tier: nil,
      kohai_balance: below_threshold,
      tier_checked_at: 1.minute.ago
    )
    
    assert_equal :none, TierService.check_tier_status(user)[:tier]
  end

  test "boundary conditions work at exact thresholds" do
    thresholds = KohaiRpcService.tier_thresholds
    
    # Just below elite
    below_elite = User.create!(
      wallet_address: "below_elite",
      tier: nil,
      kohai_balance: thresholds[:elite] - 0.01,
      tier_checked_at: 1.minute.ago
    )
    assert_equal :none, TierService.check_tier_status(below_elite)[:tier]
    
    # Exactly at elite
    at_elite = User.create!(
      wallet_address: "at_elite",
      tier: :elite,
      kohai_balance: thresholds[:elite],
      tier_checked_at: 1.minute.ago
    )
    assert_equal :elite, TierService.check_tier_status(at_elite)[:tier]
  end
end
```

### Test Pattern 2: Discount Calculation with Custom Thresholds

```ruby
class TopupProductDiscountWithCustomThresholdsTest < ActiveSupport::TestCase
  test "discount calculation respects custom thresholds" do
    thresholds = KohaiRpcService.tier_thresholds
    
    product = TopupProductItem.create!(
      name: "1000 Diamonds",
      price: 100.0,
      currency: "MYR"
    )
    
    # Elite user gets 1% discount
    elite_user = User.create!(
      wallet_address: "elite_test",
      tier: :elite,
      kohai_balance: thresholds[:elite],
      tier_checked_at: 1.minute.ago
    )
    
    discount = product.calculate_user_discount(elite_user)
    assert_equal 1, discount[:discount_percent]
    assert_equal 1.0, discount[:discount_amount]
    assert_equal 99.0, discount[:discounted_price]
  end

  test "discounted price updates when thresholds change" do
    thresholds = KohaiRpcService.tier_thresholds
    
    product = TopupProductItem.create!(
      name: "500 Diamonds",
      price: 50.0,
      currency: "MYR"
    )
    
    user = User.create!(
      wallet_address: "dynamic_test",
      tier: :grandmaster,
      kohai_balance: thresholds[:grandmaster],
      tier_checked_at: 1.minute.ago
    )
    
    # With Grandmaster tier (2% discount)
    discount = product.calculate_user_discount(user)
    assert_equal 2, discount[:discount_percent]
    assert_equal 1.0, discount[:discount_amount]
    
    # Update user's balance to legend tier
    user.update!(kohai_balance: thresholds[:legend])
    
    # Discount should now be 3%
    discount = product.calculate_user_discount(user)
    assert_equal 3, discount[:discount_percent]
    assert_equal 1.5, discount[:discount_amount]
  end
end
```

---

## Integration Testing

### Test GraphQL Queries with Custom Thresholds

```ruby
class TopupProductsQueryCustomThresholdTest < ApplicationSystemTestCase
  setup do
    @thresholds = KohaiRpcService.tier_thresholds
  end

  test "graphql query returns correct discounts for custom thresholds" do
    # Create users at different tier levels
    elite_user = User.create!(
      wallet_address: "gql_elite",
      tier: :elite,
      kohai_balance: @thresholds[:elite],
      tier_checked_at: 1.minute.ago
    )
    
    grandmaster_user = User.create!(
      wallet_address: "gql_grandmaster",
      tier: :grandmaster,
      kohai_balance: @thresholds[:grandmaster],
      tier_checked_at: 1.minute.ago
    )
    
    # Create products
    product = TopupProduct.create!(title: "Test Game", code: "test")
    item = product.topup_product_items.create!(
      name: "500 Tokens",
      price: 100.0,
      currency: "MYR"
    )
    
    # Query as Elite user
    query_elite = query_string(item.id)
    result_elite = execute_graphql(query_elite, context: { current_user: elite_user })
    
    discount_percent = result_elite.dig("data", "topupProductItem", "discountPercent")
    assert_equal 1, discount_percent  # Elite: 1%
    
    # Query as Grandmaster user
    result_grandmaster = execute_graphql(query_string(item.id), context: { current_user: grandmaster_user })
    
    discount_percent = result_grandmaster.dig("data", "topupProductItem", "discountPercent")
    assert_equal 2, discount_percent  # Grandmaster: 2%
  end
end
```

---

## Comparing Different Threshold Scenarios

Create a script to test and report differences:

```bash
#!/bin/bash

echo "📊 KOHAI Threshold Comparison Report"
echo "===================================="

test_tier_config() {
  local ELITE=$1
  local GRANDMASTER=$2
  local LEGEND=$3
  local NAME=$4
  
  echo ""
  echo "Configuration: $NAME"
  echo "  Elite: $ELITE"
  echo "  Grandmaster: $GRANDMASTER"
  echo "  Legend: $LEGEND"
  echo "---"
  
  export KOHAI_ELITE_MIN=$ELITE
  export KOHAI_GRANDMASTER_MIN=$GRANDMASTER
  export KOHAI_LEGEND_MIN=$LEGEND
  
  # Run tests and capture output
  bundle exec rails test test/models/topup_product_item_test.rb 2>&1 | tail -5
}

# Test different configurations
test_tier_config "100" "200" "300" "Testing Config (Low)"
test_tier_config "5000" "10000" "30000" "Testing Config (Medium)"
test_tier_config "50000" "500000" "3000000" "Production Config (Default)"

echo ""
echo "✅ Comparison complete!"
```

---

## Checking Thresholds at Runtime

### View Current Thresholds

```bash
# In Rails console
rails console

# Check current thresholds
KohaiRpcService.tier_thresholds

# Output:
# => {:elite=>5000.0, :grandmaster=>10000.0, :legend=>30000.0}
```

### Verify Environment Variables Are Set

```bash
# Check environment
echo $KOHAI_ELITE_MIN
echo $KOHAI_GRANDMASTER_MIN
echo $KOHAI_LEGEND_MIN

# Or in Ruby
puts "Elite: #{ENV['KOHAI_ELITE_MIN']}"
puts "Grandmaster: #{ENV['KOHAI_GRANDMASTER_MIN']}"
puts "Legend: #{ENV['KOHAI_LEGEND_MIN']}"
```

---

## Common Test Scenarios

### Scenario A: Test All Three Tiers Work Correctly

```ruby
test "all tiers work with custom thresholds" do
  thresholds = KohaiRpcService.tier_thresholds
  
  # Test tier detection
  [
    [thresholds[:elite] - 1, :none],
    [thresholds[:elite], :elite],
    [thresholds[:grandmaster] - 1, :elite],
    [thresholds[:grandmaster], :grandmaster],
    [thresholds[:legend] - 1, :grandmaster],
    [thresholds[:legend], :legend],
  ].each do |balance, expected_tier|
    user = User.create!(
      wallet_address: SecureRandom.hex(20),
      tier: expected_tier.to_s,
      kohai_balance: balance,
      tier_checked_at: 1.minute.ago
    )
    
    result = TierService.check_tier_status(user)
    assert_equal expected_tier, result[:tier], 
      "Balance #{balance} should be #{expected_tier}"
  end
end
```

### Scenario B: Test Discount Percentages

```ruby
test "discount percentages correct for custom thresholds" do
  thresholds = KohaiRpcService.tier_thresholds
  
  discounts = {
    nil => 0,
    :elite => 1,
    :grandmaster => 2,
    :legend => 3
  }
  
  discounts.each do |tier, percent|
    user = User.create!(
      wallet_address: SecureRandom.hex(20),
      tier: tier,
      kohai_balance: thresholds[tier] || 0,
      tier_checked_at: 1.minute.ago
    )
    
    status = TierService.check_tier_status(user)
    assert_equal percent, status[:discount_percent],
      "Tier #{tier} should have #{percent}% discount"
  end
end
```

---

## Summary

| Method | Use Case | Example |
|--------|----------|---------|
| **Environment Variables** | Testing, CI/CD, Local Dev | `export KOHAI_ELITE_MIN=1000` |
| **.env File** | Local development only | Add to `.env` and use dotenv |
| **Test Setup** | Per-test configuration | Set in `setup` or test method |
| **Runtime Check** | Verify current config | `KohaiRpcService.tier_thresholds` |

You now have complete flexibility to test any tier threshold configuration! 🚀
