#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  🧪 KOHAI Tier Threshold Testing Suite${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Function to run tests with given thresholds
run_test() {
    local ELITE=$1
    local GRANDMASTER=$2
    local LEGEND=$3
    local CONFIG_NAME=$4
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📋 Configuration: ${CONFIG_NAME}${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Elite Minimum:       ${BLUE}${ELITE}${NC} KOHAI"
    echo -e "  Grandmaster Minimum: ${BLUE}${GRANDMASTER}${NC} KOHAI"
    echo -e "  Legend Minimum:      ${BLUE}${LEGEND}${NC} KOHAI"
    echo ""
    
    # Export environment variables
    export KOHAI_ELITE_MIN=$ELITE
    export KOHAI_GRANDMASTER_MIN=$GRANDMASTER
    export KOHAI_LEGEND_MIN=$LEGEND
    
    # Run the test
    echo -e "${BLUE}Running tests...${NC}"
    bundle exec rails test test/models/topup_product_item_test.rb -v 2>&1 | tail -20
    
    TEST_RESULT=$?
    echo ""
    
    if [ $TEST_RESULT -eq 0 ]; then
        echo -e "${GREEN}✅ Tests PASSED for $CONFIG_NAME${NC}"
    else
        echo -e "${RED}❌ Tests FAILED for $CONFIG_NAME${NC}"
    fi
    echo ""
}

# Test Configuration 1: Ultra-low (for quick testing)
run_test "100" "200" "300" "Ultra-Low (Testing)"

# Test Configuration 2: Low (easier testing)
run_test "1000" "5000" "10000" "Low (Easy Testing)"

# Test Configuration 3: Custom (your preferred testing values)
run_test "5000" "10000" "30000" "Custom (Medium Testing)"

# Test Configuration 4: Default (production-like)
run_test "50000" "500000" "3000000" "Default (Production)"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  ✅ Testing Suite Complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "💡 To run tests with specific thresholds manually:"
echo "   export KOHAI_ELITE_MIN=5000"
echo "   export KOHAI_GRANDMASTER_MIN=10000"
echo "   export KOHAI_LEGEND_MIN=30000"
echo "   bundle exec rails test test/models/topup_product_item_test.rb"
echo ""
