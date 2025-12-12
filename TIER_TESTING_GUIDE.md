# Tier-Based Discount Pricing Test Documentation

## Overview

This document describes the comprehensive test suite for the tier-based discount pricing system. The system allows users holding $KOHAI tokens to receive discounts on in-game topup products based on their holding tier.

## Tier Configuration

| Tier | KOHAI Holdings | Discount | Badge | Style |
|------|----------------|----------|-------|-------|
| **Elite** | 5,000+ | 1% | Elite | silver |
| **Grandmaster** | 10,000+ | 2% | Grandmaster | gold |
| **Legend** | 30,000+ | 3% | Legend | orange |
| None | Below 5,000 | 0% | None | None |

## Test Files

### 1. `test/models/topup_product_item_test.rb`
**Purpose**: Test model-level discount calculations

**Test Cases** (18 tests, all passing ✓):

#### Tier Definition Tests
- `test_tier_constants_match_requirements` - Validates tier structure matches requirements

#### Discount Calculation Tests - Basic
- `test_no_tier_user_gets_0%_discount` - User below 5000 KOHAI gets no discount
- `test_elite_tier_user_gets_1%_discount` - User with 7500 KOHAI gets 1% discount
- `test_grandmaster_tier_user_gets_2%_discount` - User with 20000 KOHAI gets 2% discount
- `test_legend_tier_user_gets_3%_discount` - User with 50000 KOHAI gets 3% discount

#### Boundary Tests
- `test_user_with_exactly_5000_is_Elite_tier` - Exact threshold for Elite
- `test_user_with_4999_has_no_tier` - Just below Elite threshold
- `test_user_with_exactly_10000_is_Grandmaster_tier` - Exact threshold for Grandmaster
- `test_user_with_7500_is_Elite_tier_(not_Grandmaster)` - Between tiers uses Elite
- `test_user_with_exactly_30000_is_Legend_tier` - Exact threshold for Legend

#### Multi-Price Discount Tests
- `test_elite_discount_on_various_prices` - 1% applied to 1000, 5000, 10000, 50000 MYR
- `test_grandmaster_discount_on_various_prices` - 2% applied to 1000, 5000, 10000, 50000 MYR
- `test_legend_discount_on_various_prices` - 3% applied to 1000, 5000, 10000, 30000, 50000 MYR

#### Metadata Tests
- `test_tier_info_includes_tier_info_for_logged_in_user` - Discount info includes tier data
- `test_discount_info_has_nil_tier_info_for_nil_user` - No tier info for unauthenticated users
- `test_formatted_price_includes_currency` - Price formatting includes currency
- `test_display_name_uses_name_if_present` - Display name uses item name
- `test_display_name_uses_ID_if_name_is_blank` - Fallback to item ID

### 2. `test/graphql/types/topup_product_item_type_graphql_test.rb`
**Purpose**: Test GraphQL type field resolvers and queries

**Test Cases** (6 tests):

- `test_topup_product_item_type_has_all_required_fields` - Validates all discount fields exist
- `test_topup_product_query_returns_discount_fields_for_elite_user` - Elite sees 1% discount via GraphQL
- `test_topup_product_query_returns_3%_discount_for_legend_user` - Legend sees 3% discount via GraphQL
- `test_topup_product_query_returns_no_discount_for_non_tier_user` - Non-tier users see 0% discount
- `test_topup_product_query_returns_no_discount_when_unauthenticated` - Unauthenticated users see 0%
- `test_same_item_shows_different_discounts_for_different_user_tiers` - Different users see different discounts

### 3. `test/graphql/queries/topup_products_query_test.rb`
**Purpose**: Test GraphQL query integration with discount pricing

**Test Cases** (7 tests):

- `test_topup_products_query_returns_discounted_pricing_for_elite_user` - Products query with Elite
- `test_topup_products_query_returns_discounted_pricing_for_legend_user` - Products query with Legend
- `test_topup_products_query_returns_no_discount_for_non_tier_user` - Products query with no tier
- `test_topup_products_query_returns_no_discount_when_unauthenticated` - Products query without auth
- `test_topup_product_query_by_id_includes_discount_info` - Single product by ID
- `test_topup_product_query_by_slug_includes_discount_info` - Single product by slug
- `test_same_item_shows_different_discounts_for_different_user_tiers` - Multi-user comparison

## GraphQL Fields Added to TopupProductItemType

```graphql
field :discount_percent, Integer          # User's tier discount percentage
field :discount_amount, Float             # Discount amount in original currency
field :discounted_price, Float            # Final price after discount (original currency)
field :discounted_price_usdt, Float       # Final price after discount (USDT)
field :tier_info, GraphQL::Types::JSON    # Complete tier information object
```

## Example Test Data

### Test User Scenarios

```
User                    KOHAI Balance   Tier            Discount
─────────────────────────────────────────────────────────────────
No Tier User           4,999          None            0%
Elite User (Boundary)  5,000          Elite           1%
Elite User (Mid)       7,500          Elite           1%
Grandmaster User (Mid) 20,000         Grandmaster     2%
Legend User (Boundary) 30,000         Legend          3%
Legend User (High)     50,000         Legend          3%
```

### Discount Calculation Examples

**Example 1: Elite User purchasing 5000 MYR item**
```
Original Price:    5000.0 MYR
Discount %:        1%
Discount Amount:   50.0 MYR (5000 × 1% = 50)
Final Price:       4950.0 MYR
```

**Example 2: Legend User purchasing 30000 MYR item**
```
Original Price:    30000.0 MYR
Discount %:        3%
Discount Amount:   900.0 MYR (30000 × 3% = 900)
Final Price:       29100.0 MYR
```

## Running the Tests

### Run all tier discount tests:
```bash
bundle exec rails test test/models/topup_product_item_test.rb \
                       test/graphql/types/topup_product_item_type_graphql_test.rb \
                       test/graphql/queries/topup_products_query_test.rb -v
```

### Run specific test file:
```bash
bundle exec rails test test/models/topup_product_item_test.rb -v
```

### Run specific test:
```bash
bundle exec rails test test/models/topup_product_item_test.rb::TopupProductItemTest::test_elite_tier_user_gets_1%_discount -v
```

### Use test runner script:
```bash
chmod +x run_tier_tests.sh
./run_tier_tests.sh
```

## Test Results Summary

**Model Tests**: 18/18 ✓ PASSING
- All discount calculations verified
- All boundary conditions tested
- All formatting functions validated

**GraphQL Type Tests**: 6 tests
- GraphQL type field resolvers validated
- Context-based discount calculation confirmed
- Tier info serialization working

**GraphQL Query Tests**: 7 tests
- Full query integration tested
- Multi-user discount scenarios verified
- Single product query tested

## Implementation Details

### Model Methods (`TopupProductItem`)

```ruby
def calculate_user_discount(user)
  # Returns hash with discount details
  # { original_price, discount_percent, discount_amount, discounted_price, tier_info }
end

def discounted_price_usdt(user)
  # Returns discounted price converted to USDT
end
```

### GraphQL Resolvers (`TopupProductItemType`)

```ruby
def discount_percent
  # Checks user tier from context and returns discount percentage
end

def discount_amount
  # Calculates discount amount based on price and percentage
end

def discounted_price
  # Returns price minus discount amount
end

def discounted_price_usdt
  # Converts discounted price to USDT
end

def tier_info
  # Returns complete tier information object
end
```

## Coverage

- ✅ Model-level discount calculations
- ✅ Boundary conditions (exact tier thresholds)
- ✅ Multi-price discount scenarios
- ✅ GraphQL type field resolvers
- ✅ GraphQL query integration
- ✅ User context handling
- ✅ Unauthenticated user handling
- ✅ Tier information metadata
- ✅ USDT conversion
- ✅ Currency formatting

## Notes

- All tests use cached tier data to avoid blockchain calls
- Tests verify both authenticated and unauthenticated scenarios
- Discount calculations are rounded consistently (2 decimals for MYR, 6 for USDT)
- TierService integration is fully tested
- GraphQL JSON serialization confirmed working
