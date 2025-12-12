#!/bin/bash

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Custom KOHAI Threshold Testing Examples${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Example 1: Check current thresholds
echo -e "${YELLOW}Example 1: Check Current Thresholds${NC}"
echo "Command: KohaiRpcService.tier_thresholds"
echo ""
cd /Users/twebcommerce/Projects/kohai-game-web3
rails console <<EOF
puts KohaiRpcService.tier_thresholds.inspect
exit
EOF
echo ""

# Example 2: Test with ultra-low values
echo -e "${YELLOW}Example 2: Test with Ultra-Low Values (100, 200, 300)${NC}"
echo "These make testing VERY easy - users get tier with small amounts"
echo ""
KOHAI_ELITE_MIN=100 \
KOHAI_GRANDMASTER_MIN=200 \
KOHAI_LEGEND_MIN=300 \
bundle exec rails test test/services/tier_threshold_test.rb -v --seed=1000 2>&1 | grep -E "test_|Finished" | head -15
echo ""

# Example 3: Test with custom values
echo -e "${YELLOW}Example 3: Test with Your Custom Values (5k, 10k, 30k)${NC}"
echo "These are good for realistic testing"
echo ""
KOHAI_ELITE_MIN=5000 \
KOHAI_GRANDMASTER_MIN=10000 \
KOHAI_LEGEND_MIN=30000 \
bundle exec rails test test/services/tier_threshold_test.rb -v --seed=1000 2>&1 | grep -E "test_|Finished" | head -15
echo ""

# Example 4: Show test output with specific thresholds
echo -e "${YELLOW}Example 4: Detailed Test Output (Low Thresholds)${NC}"
echo "Running 3 key tests with ultra-low thresholds..."
echo ""
KOHAI_ELITE_MIN=100 \
KOHAI_GRANDMASTER_MIN=200 \
KOHAI_LEGEND_MIN=300 \
bundle exec rails test test/services/tier_threshold_test.rb::TierThresholdTest::test_user_at_exactly_elite_threshold_is_elite \
  test/services/tier_threshold_test.rb::TierThresholdTest::test_user_at_exactly_grandmaster_threshold_is_grandmaster \
  test/services/tier_threshold_test.rb::TierThresholdTest::test_user_at_exactly_legend_threshold_is_legend \
  -v 2>&1 | tail -20
echo ""

echo -e "${GREEN}✅ All examples complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Modify KOHAI_ELITE_MIN, KOHAI_GRANDMASTER_MIN, KOHAI_LEGEND_MIN values"
echo "2. Run: bundle exec rails test test/services/tier_threshold_test.rb -v"
echo "3. Or use: ./run_threshold_tests.sh"
echo ""
