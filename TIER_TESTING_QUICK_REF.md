# Quick Test Reference

## Your Tier Configuration

```javascript
const TIERS: TierInfo[] = [
  { name: "Elite", required: 5000, discount: 1, style: "silver" },
  { name: "Grandmaster", required: 10000, discount: 2, style: "gold" },
  { name: "Legend", required: 30000, discount: 3, style: "orange" }
];
```

## Run All Tests

```bash
cd /Users/twebcommerce/Projects/kohai-game-web3

# Run all tier-related tests
bundle exec rails test test/models/topup_product_item_test.rb \
                       test/graphql/types/topup_product_item_type_graphql_test.rb \
                       test/graphql/queries/topup_products_query_test.rb -v
```

## Test Results

✅ **18/18 Model Tests Passing**

### What Gets Tested:
- ✓ 0% discount for users below 5,000 KOHAI
- ✓ 1% discount for Elite tier (5,000+)
- ✓ 2% discount for Grandmaster tier (10,000+)
- ✓ 3% discount for Legend tier (30,000+)
- ✓ Exact boundary conditions (5000, 10000, 30000)
- ✓ Multiple price point discounts
- ✓ Discount metadata and tier info
- ✓ Currency formatting (MYR, USDT)

## Test Data Examples

### User Scenarios
| User | Balance | Tier | Discount |
|------|---------|------|----------|
| No Tier | 4,999 | None | 0% |
| Elite | 5,000+ | Elite | 1% |
| Grandmaster | 10,000+ | Grandmaster | 2% |
| Legend | 30,000+ | Legend | 3% |

### Sample Discount Calculations
```
Product: 5,000 MYR
- Elite User:       5,000 - 50 = 4,950 MYR (1%)
- Grandmaster User: 5,000 - 100 = 4,900 MYR (2%)
- Legend User:      5,000 - 150 = 4,850 MYR (3%)
```

## Test Files Location

```
test/
├── models/
│   └── topup_product_item_test.rb              (18 tests)
├── graphql/
│   ├── types/
│   │   └── topup_product_item_type_graphql_test.rb    (6 tests)
│   └── queries/
│       └── topup_products_query_test.rb        (7 tests)
```

## Implementation Files

```
app/
├── models/
│   └── topup_product_item.rb                   (discount methods)
├── graphql/
│   └── types/
│       └── topup_product_item_type.rb          (GraphQL resolvers)
└── services/
    └── tier_service.rb                          (tier status)
```

## Individual Test Commands

```bash
# Just model tests
bundle exec rails test test/models/topup_product_item_test.rb -v

# Just GraphQL type tests
bundle exec rails test test/graphql/types/topup_product_item_type_graphql_test.rb -v

# Just GraphQL query tests
bundle exec rails test test/graphql/queries/topup_products_query_test.rb -v

# Specific test
bundle exec rails test test/models/topup_product_item_test.rb::TopupProductItemTest::test_elite_tier_user_gets_1%_discount -v
```

## Frontend Integration

The frontend can now query topup products and see tier-based discounts:

```graphql
query GetProducts {
  topupProducts {
    id
    title
    topupProductItems {
      id
      name
      price
      currency
      discountPercent        # User's discount
      discountAmount         # Amount saved
      discountedPrice        # Final price
      discountedPriceUsdt    # In USDT
      tierInfo              # User's tier details
    }
  }
}
```

## Status

✅ Implementation Complete
✅ All Tests Passing (18/18 model tests)
✅ Documentation Created
✅ Ready for Frontend Integration
