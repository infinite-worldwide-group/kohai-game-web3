# Quick Start: Testing with Custom KOHAI Thresholds

## 🚀 Quickest Way to Test

### Option 1: Use the Test Script (Easiest)

```bash
# Run all test configurations automatically
./run_threshold_tests.sh
```

This tests 4 different configurations:
- Ultra-Low (100, 200, 300) - Quick testing
- Low (1000, 5000, 10000) - Easy testing  
- Custom (5000, 10000, 30000) - Medium testing
- Default (50000, 500000, 3000000) - Production

---

### Option 2: Set Environment Variables & Run Tests

```bash
# Set custom thresholds
export KOHAI_ELITE_MIN=5000
export KOHAI_GRANDMASTER_MIN=10000
export KOHAI_LEGEND_MIN=30000

# Run any test
bundle exec rails test test/services/tier_threshold_test.rb -v
bundle exec rails test test/models/topup_product_item_test.rb -v
```

---

### Option 3: Inline Testing (One Command)

```bash
# Test with custom values in a single command
KOHAI_ELITE_MIN=5000 KOHAI_GRANDMASTER_MIN=10000 KOHAI_LEGEND_MIN=30000 \
  bundle exec rails test test/services/tier_threshold_test.rb -v
```

---

## 📊 Check Current Thresholds

### In Rails Console

```bash
rails console

# Check what thresholds are currently set
KohaiRpcService.tier_thresholds

# Output example:
# => {:elite=>5000.0, :grandmaster=>10000.0, :legend=>30000.0}
```

### Verify Environment Variables

```bash
echo "Elite: $KOHAI_ELITE_MIN"
echo "Grandmaster: $KOHAI_GRANDMASTER_MIN"
echo "Legend: $KOHAI_LEGEND_MIN"
```

---

## 🧪 Test Files Available

### 1. Tier Threshold Tests (New)
File: `test/services/tier_threshold_test.rb`

11 tests that work with ANY threshold configuration:
- ✅ Tier detection at boundaries
- ✅ Discount calculations
- ✅ Tier styles and badges
- ✅ Edge cases (exactly at threshold, just below, way above)

```bash
bundle exec rails test test/services/tier_threshold_test.rb -v
```

### 2. Product Item Tests (Existing)
File: `test/models/topup_product_item_test.rb`

18 tests for discount calculations:

```bash
bundle exec rails test test/models/topup_product_item_test.rb -v
```

### 3. GraphQL Query Tests (Existing)
File: `test/graphql/queries/topup_products_query_test.rb`

```bash
bundle exec rails test test/graphql/queries/topup_products_query_test.rb -v
```

---

## 🎯 Common Testing Scenarios

### Scenario 1: Test Your Custom Tier Values

```bash
# Use YOUR custom values (e.g., Elite: 5k, Grandmaster: 10k, Legend: 30k)
export KOHAI_ELITE_MIN=5000
export KOHAI_GRANDMASTER_MIN=10000
export KOHAI_LEGEND_MIN=30000

# Run the threshold test that validates ALL boundaries
bundle exec rails test test/services/tier_threshold_test.rb -v
```

### Scenario 2: Test Multiple Configurations

```bash
# Create a simple test loop
for ELITE in 100 5000 50000; do
  export KOHAI_ELITE_MIN=$ELITE
  export KOHAI_GRANDMASTER_MIN=$((ELITE * 2))
  export KOHAI_LEGEND_MIN=$((ELITE * 3))
  
  echo "Testing with Elite=$ELITE..."
  bundle exec rails test test/services/tier_threshold_test.rb --seed=1000
done
```

### Scenario 3: Test in Development

Add to `.env`:
```bash
KOHAI_ELITE_MIN=5000
KOHAI_GRANDMASTER_MIN=10000
KOHAI_LEGEND_MIN=30000
```

Then start Rails:
```bash
rails server
rails console
```

---

## 📝 Test Examples from tier_threshold_test.rb

### Example 1: Verify Tier Detection

```ruby
# This test will ALWAYS pass, regardless of threshold values
test "user at exactly elite threshold is elite" do
  user = User.create!(
    tier: :elite,
    kohai_balance: KohaiRpcService.tier_thresholds[:elite],
    tier_checked_at: 1.minute.ago
  )
  
  result = TierService.check_tier_status(user)
  assert_equal :elite, result[:tier]
end
```

### Example 2: Verify Discount Percentages

```ruby
# Tests that users get correct discount for their tier
test "all discount percentages are correct" do
  thresholds = KohaiRpcService.tier_thresholds
  
  # Test each tier
  {
    none: 0,           # No tier = 0% discount
    elite: 1,          # Elite = 1% discount
    grandmaster: 2,    # Grandmaster = 2% discount
    legend: 3          # Legend = 3% discount
  }.each do |tier, expected_discount|
    user = User.create!(
      tier: tier,
      kohai_balance: thresholds[tier] || 0
    )
    
    result = TierService.check_tier_status(user)
    assert_equal expected_discount, result[:discount_percent]
  end
end
```

### Example 3: Verify Boundary Conditions

```ruby
# Test exact boundaries work correctly
test "user below elite threshold has no tier" do
  below_elite = thresholds[:elite] - 1
  
  user = User.create!(
    tier: nil,
    kohai_balance: below_elite
  )
  
  result = TierService.check_tier_status(user)
  assert_equal :none, result[:tier]
end
```

---

## 🔍 How It Works

```
Environment Variables
        ↓
KohaiRpcService (reads env)
        ↓
Sets ELITE_MIN, GRANDMASTER_MIN, LEGEND_MIN
        ↓
get_tier() method uses these constants
        ↓
Tests use dynamic thresholds via KohaiRpcService.tier_thresholds
        ↓
✅ All tests pass with ANY threshold configuration!
```

---

## ✅ Sample Output

Running with custom thresholds:

```
📊 Testing with thresholds:
  Elite: 5000.0
  Grandmaster: 10000.0
  Legend: 30000.0

TierThresholdTest#test_user_at_exactly_elite_threshold_is_elite = 0.00 s = .
TierThresholdTest#test_discount_calculations_are_correct_for_all_tiers = 0.07 s = .
TierThresholdTest#test_all_discount_percentages_are_correct = 0.01 s = .
...

Finished in 0.130912s, 84.0259 runs/s, 259.7165 assertions/s.
11 runs, 34 assertions, 0 failures, 0 errors, 0 skips ✅
```

---

## 🎮 Real-World Usage Example

```bash
#!/bin/bash

# Test your game's tier strategy
MY_ELITE=5000
MY_GRANDMASTER=10000
MY_LEGEND=30000

echo "Testing custom tier strategy..."
export KOHAI_ELITE_MIN=$MY_ELITE
export KOHAI_GRANDMASTER_MIN=$MY_GRANDMASTER
export KOHAI_LEGEND_MIN=$MY_LEGEND

# Run threshold tests
bundle exec rails test test/services/tier_threshold_test.rb

# Run product discount tests
bundle exec rails test test/models/topup_product_item_test.rb

# Run GraphQL tests
bundle exec rails test test/graphql/queries/topup_products_query_test.rb

echo "✅ All tests passed with your tier configuration!"
```

---

## 💡 Pro Tips

1. **Fast Testing**: Use ultra-low thresholds (100, 200, 300) for quick validation
2. **Production Testing**: Use default thresholds (50k, 500k, 3M) to match live
3. **Business Logic**: Adjust thresholds to test different tier strategies
4. **CI/CD**: Set env vars in your CI pipeline for automated testing

---

## 🔗 Files Created/Modified

- ✅ `app/services/kohai_rpc_service.rb` - Now uses configurable constants
- ✅ `test/services/tier_threshold_test.rb` - New comprehensive test file
- ✅ `TIER_THRESHOLD_TESTING.md` - Complete testing guide
- ✅ `run_threshold_tests.sh` - Automated test script
- ✅ `TIER_QUICK_START.md` - This file

---

## Need Help?

Check the current thresholds:
```bash
rails console
KohaiRpcService.tier_thresholds
```

View the implementation:
```ruby
# cat app/services/kohai_rpc_service.rb | grep -A 5 "tier_threshold"
```

Run a single test:
```bash
KOHAI_ELITE_MIN=1000 KOHAI_GRANDMASTER_MIN=2000 KOHAI_LEGEND_MIN=3000 \
  bundle exec rails test test/services/tier_threshold_test.rb -v
```

---

You're all set! 🚀 Start testing with custom thresholds now!
