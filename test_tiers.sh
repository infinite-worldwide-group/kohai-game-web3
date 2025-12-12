#!/bin/bash

# Test Tier Pricing System
# This script runs all tests related to the tier-based discounted pricing feature

set -e

echo "=========================================="
echo "Testing Tier-Based Discount Pricing System"
echo "=========================================="
echo ""

echo "Test Configuration:"
echo "- Elite Tier: 5,000+ KOHAI = 1% discount"
echo "- Grandmaster Tier: 10,000+ KOHAI = 2% discount"
echo "- Legend Tier: 30,000+ KOHAI = 3% discount"
echo ""

# Run model tests
echo "1. Running TopupProductItem Model Tests..."
bundle exec rails test test/models/topup_product_item_test.rb -v

echo ""
echo "2. Running TopupProductItemType GraphQL Tests..."
bundle exec rails test test/graphql/types/topup_product_item_type_test.rb -v

echo ""
echo "3. Running TopupProducts Query Integration Tests..."
bundle exec rails test test/graphql/queries/topup_products_query_test.rb -v

echo ""
echo "=========================================="
echo "All Tests Completed Successfully!"
echo "=========================================="
echo ""
echo "Summary:"
echo "✓ Model calculations for tier-based discounts"
echo "✓ GraphQL type field resolvers"
echo "✓ GraphQL query integration with discount pricing"
echo "✓ Boundary testing for tier transitions"
echo "✓ Multi-user discount scenarios"
echo ""
