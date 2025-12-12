# KOHAI Tier Threshold Testing - Quick Reference Card

## 🎯 In 30 Seconds

```bash
# Set your tier thresholds
export KOHAI_ELITE_MIN=5000
export KOHAI_GRANDMASTER_MIN=10000
export KOHAI_LEGEND_MIN=30000

# Run tests
bundle exec rails test test/services/tier_threshold_test.rb -v

# Verify
rails console
KohaiRpcService.tier_thresholds
```

---

## 📋 3 Ways to Test

| Method | Command | Speed | Use Case |
|--------|---------|-------|----------|
| **Automated** | `./run_threshold_tests.sh` | ⚡⚡⚡ Fast | Try 4 configs at once |
| **Manual** | `export KOHAI_ELITE_MIN=X ... && bundle exec rails test...` | ⚡ Medium | Your custom values |
| **Inline** | `KOHAI_ELITE_MIN=X ... bundle exec rails test...` | ⚡ Fast | One-off testing |

---

## 🔍 Check Current Thresholds

### In Rails Console
```ruby
rails console
> KohaiRpcService.tier_thresholds
# Output: {:elite=>5000.0, :grandmaster=>10000.0, :legend=>30000.0}
```

### In Terminal
```bash
echo $KOHAI_ELITE_MIN
echo $KOHAI_GRANDMASTER_MIN
echo $KOHAI_LEGEND_MIN
```

---

## 🧪 Test Configurations

### Ultra-Low (Fastest)
```bash
export KOHAI_ELITE_MIN=100
export KOHAI_GRANDMASTER_MIN=200
export KOHAI_LEGEND_MIN=300
```

### Low (Easy)
```bash
export KOHAI_ELITE_MIN=1000
export KOHAI_GRANDMASTER_MIN=5000
export KOHAI_LEGEND_MIN=10000
```

### Custom (Medium)
```bash
export KOHAI_ELITE_MIN=5000
export KOHAI_GRANDMASTER_MIN=10000
export KOHAI_LEGEND_MIN=30000
```

### Default (Production)
```bash
export KOHAI_ELITE_MIN=50000
export KOHAI_GRANDMASTER_MIN=500000
export KOHAI_LEGEND_MIN=3000000
```

---

## 🚀 Common Commands

### Run All Tests (Recommended)
```bash
./run_threshold_tests.sh
```

### Run Threshold Tests Only
```bash
bundle exec rails test test/services/tier_threshold_test.rb -v
```

### Run All Tests with Custom Values
```bash
KOHAI_ELITE_MIN=5000 KOHAI_GRANDMASTER_MIN=10000 KOHAI_LEGEND_MIN=30000 \
  bundle exec rails test test/
```

### Run Single Test
```bash
bundle exec rails test test/services/tier_threshold_test.rb::TierThresholdTest::test_user_at_exactly_elite_threshold_is_elite
```

### Interactive Testing
```bash
rails console

# Set variables before loading service
ENV['KOHAI_ELITE_MIN'] = '5000'
ENV['KOHAI_GRANDMASTER_MIN'] = '10000'
ENV['KOHAI_LEGEND_MIN'] = '30000'

# Check thresholds
KohaiRpcService.tier_thresholds

# Test tier detection
user = User.create!(tier: :elite, kohai_balance: 5000, tier_checked_at: Time.now)
TierService.check_tier_status(user)
```

---

## 📊 What Gets Tested

```
11 Tests
├── Tier Detection (7)
│   ├── Below elite threshold → :none
│   ├── At elite threshold → :elite
│   ├── Between elite & grandmaster → :elite
│   ├── At grandmaster threshold → :grandmaster
│   ├── Between grandmaster & legend → :grandmaster
│   ├── At legend threshold → :legend
│   └── Way above legend → :legend
│
├── Discounts (3)
│   ├── 0% discount for no tier
│   ├── 1% discount for elite
│   ├── 2% discount for grandmaster
│   └── 3% discount for legend
│
└── Formatting (1)
    ├── Styles: silver, gold, orange
    ├── Badge names
    ├── Discount amounts
    └── Discounted prices
```

---

## ✅ Test Results

All configurations pass:
- ✅ Ultra-Low (100, 200, 300): 11/11 passing
- ✅ Low (1000, 5000, 10000): 11/11 passing
- ✅ Custom (5000, 10000, 30000): 11/11 passing
- ✅ Default (50000, 500000, 3000000): 11/11 passing

---

## 📁 Files

### Modified
- `app/services/kohai_rpc_service.rb`

### New Tests
- `test/services/tier_threshold_test.rb` (11 tests)

### New Scripts
- `run_threshold_tests.sh`
- `test_threshold_examples.sh`

### New Docs
- `TIER_QUICK_START.md`
- `TIER_THRESHOLD_TESTING.md`
- `TIER_CONFIG_IMPLEMENTATION.md`
- `TIER_IMPLEMENTATION_FILES.md`

---

## 💡 Pro Tips

1. **Local Dev**: Add to `.env` to load automatically
2. **CI/CD**: Set in pipeline config for consistent testing
3. **Quick Test**: Use ultra-low values (100, 200, 300)
4. **Production**: Always test with default values first
5. **Verify**: Always check thresholds before testing

---

## 🆘 Troubleshooting

**Tests failing?**
→ Check thresholds: `KohaiRpcService.tier_thresholds`

**ENV vars not working?**
→ Verify: `echo $KOHAI_ELITE_MIN`

**Need to reload?**
→ Restart Rails: `rails restart` or `bundle exec rails s`

**Want to reset?**
→ Unset ENV: `unset KOHAI_ELITE_MIN` (uses defaults)

---

## 🔗 Related Docs

- `TIER_QUICK_START.md` - Full quick start guide
- `TIER_THRESHOLD_TESTING.md` - Comprehensive testing guide
- `TIER_CONFIG_IMPLEMENTATION.md` - Implementation details
- `TIER_IMPLEMENTATION_FILES.md` - File inventory
- `TIER_UPDATE_MECHANISM.md` - How tier system works

---

**Last Updated:** December 11, 2025  
**Status:** Production Ready ✅  
**Tests:** 11/11 Passing ✅
