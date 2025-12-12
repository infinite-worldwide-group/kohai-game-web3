# How Backend Updates User's Current Tier

## Overview

The tier system is **on-demand** and **cache-based**. The backend doesn't continuously poll the blockchain; instead, it:
1. **Checks cache first** (within 5 minutes)
2. **Fetches from blockchain** when cache is stale or force-refreshed
3. **Caches result** on the user record for future use

---

## Architecture Diagram

```
User Request
    ↓
TierService.check_tier_status(user, force_refresh: false)
    ↓
    ├─ Is tier_checked_at > 5 minutes ago? 
    │  └─ YES → Return cached tier data from user.tier, user.kohai_balance
    │
    └─ NO (cache miss or expired)
       ↓
       KohaiRpcService.get_tier(wallet_address)
           ↓
           KohaiRpcService.get_kohai_balance(wallet_address)
               ↓
               Solana RPC → getTokenAccountsByOwner
               ↓
               Returns: $KOHAI balance
       ↓
       Determine tier based on balance:
       - 3,000,000+ → :legend (3% discount)
       - 500,000-2,999,999 → :grandmaster (2% discount)
       - 50,000-499,999 → :elite (1% discount)
       - Below 50,000 → :none (0% discount)
       ↓
       TierService.cache_tier_status(user, tier_info)
           ↓
           UPDATE users SET tier, kohai_balance, tier_checked_at
       ↓
       Return tier information
```

---

## Data Flow

### 1. User Database Fields (Tier Caching)

**Table: `users`** (Added via migration `20251120083829_add_tier_fields_to_users.rb`)

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  wallet_address VARCHAR NOT NULL UNIQUE,
  
  -- Tier caching fields
  tier VARCHAR,                              -- 'elite', 'grandmaster', 'legend', or NULL
  kohai_balance DECIMAL(18,6),               -- User's $KOHAI token balance
  tier_checked_at DATETIME,                  -- When tier was last checked/cached
  
  -- Other fields...
  email VARCHAR,
  email_verified_at DATETIME,
  auth_code VARCHAR,
  created_at DATETIME,
  updated_at DATETIME
);

CREATE INDEX index_users_on_tier ON users(tier);
```

---

## Update Mechanisms

### Mechanism 1: On-Demand (During Purchase)

**When:** User initiates a purchase order

**File:** `app/graphql/mutations/orders/create_order.rb`

```ruby
# Line 76-77: Force refresh tier during purchase
tier_status = TierService.check_tier_status(current_user, force_refresh: true)

# Line 80-83: Calculate discounted price with fresh tier
discount_calculation = TierService.calculate_discounted_price(
  original_amount,
  current_user,
  force_refresh: true
)

# Line 132: Store tier at time of purchase
tier_at_purchase: tier_info[:tier_name]
```

**Why `force_refresh: true`?** 
- Ensures user gets most current discount based on latest blockchain balance
- User may have purchased more $KOHAI tokens since last check
- Prevents stale tier data from being used in financial transactions

**Flow:**
```
user.create_order() 
  → TierService.check_tier_status(force_refresh: true)
    → KohaiRpcService.get_tier() [blockchain call]
      → Updates users.tier, users.kohai_balance, users.tier_checked_at
  → Returns fresh tier data
  → Applies discount to order
  → Saves order with tier_at_purchase
```

---

### Mechanism 2: Cached (Automatic, Within 5 Minutes)

**When:** Tier is checked within 5 minutes of previous check

**File:** `app/services/tier_service.rb` (Lines 15-31)

```ruby
def check_tier_status(user, force_refresh: false)
  return default_status unless user&.wallet_address.present?

  # Check if cached tier is still fresh (< 5 minutes old)
  if !force_refresh && user.tier_checked_at.present? && user.tier_checked_at > 5.minutes.ago
    Rails.logger.info "Using cached tier for user #{user.id} (checked #{time_ago_in_words(user.tier_checked_at)} ago)"

    return {
      tier: user.tier&.to_sym || :none,
      tier_name: user.tier&.titleize,
      discount_percent: discount_for_tier(user.tier),
      referral_percent: discount_for_tier(user.tier),
      badge: user.tier&.titleize,
      style: style_for_tier(user.tier),
      balance: user.kohai_balance || 0.0
    }
  end
  
  # Cache expired or force_refresh: true → fetch from blockchain
  # ...
end
```

**Advantages:**
- Reduces blockchain RPC calls
- Faster response times (database read instead of network call)
- Sufficient for real-time user experience (5-minute window)

---

### Mechanism 3: Cache Update (After Blockchain Fetch)

**When:** Cache is stale and fresh tier is fetched from blockchain

**File:** `app/services/tier_service.rb` (Lines 89-98)

```ruby
def cache_tier_status(user, tier_info)
  user.update_columns(
    tier: tier_info[:tier],                    # 'elite', 'grandmaster', 'legend', or nil
    kohai_balance: tier_info[:balance],        # Float from blockchain
    tier_checked_at: Time.current              # NOW
  )
rescue => e
  Rails.logger.warn "Failed to cache tier status for user #{user.id}: #{e.message}"
end
```

**Why `update_columns` instead of `update!`?**
- Bypasses ActiveRecord callbacks and validations
- Faster database update
- Only updates tier-related columns (no timestamp changes for updated_at)

---

## Tier Determination Logic

**File:** `app/services/kohai_rpc_service.rb` (Lines 56-80+)

```ruby
def get_tier(wallet_address)
  balance = get_kohai_balance(wallet_address)  # From Solana blockchain

  case balance
  when 3_000_000..Float::INFINITY
    {
      tier: :legend,
      tier_name: "Legend",
      discount_percent: 3,
      referral_percent: 3,
      badge: "Legend",
      style: "orange",
      balance: balance
    }
  when 500_000...3_000_000
    {
      tier: :grandmaster,
      tier_name: "Grandmaster",
      discount_percent: 2,
      referral_percent: 2,
      badge: "Grandmaster",
      style: "gold",
      balance: balance
    }
  when 50_000...500_000
    {
      tier: :elite,
      tier_name: "Elite",
      discount_percent: 1,
      referral_percent: 1,
      badge: "Elite",
      style: "silver",
      balance: balance
    }
  else
    { tier: :none, discount_percent: 0, ... }
  end
end
```

**Tier Thresholds:**
| Tier | Minimum $KOHAI | Discount | Style |
|------|---|---|---|
| Legend | 3,000,000 | 3% | orange (glowing) |
| Grandmaster | 500,000 | 2% | gold |
| Elite | 50,000 | 1% | silver |
| None | 0 | 0% | (none) |

---

## Blockchain Integration

### Getting KOHAI Balance

**File:** `app/services/kohai_rpc_service.rb` (Lines 30-49)

```ruby
def get_kohai_balance(wallet_address)
  kohai_mint = ENV.fetch("KOHAI_TOKEN_MINT")

  response = get_token_accounts_by_owner(wallet_address, kohai_mint)

  if response["result"] && response["result"]["value"].present?
    token_accounts = response["result"]["value"]

    # Sum all token accounts (user might have balance in multiple accounts)
    total_balance = token_accounts.sum do |account|
      account.dig("account", "data", "parsed", "info", "tokenAmount", "uiAmount")&.to_f || 0.0
    end

    total_balance
  else
    0.0
  end
rescue => e
  Rails.logger.error "Failed to fetch KOHAI balance for #{wallet_address}: #{e.message}"
  0.0
end
```

### RPC Call

```ruby
def get_token_accounts_by_owner(owner_address, mint_address)
  body = {
    jsonrpc: "2.0",
    id: 1,
    method: "getTokenAccountsByOwner",  # Solana JSON-RPC method
    params: [
      owner_address,
      { mint: mint_address },           # Filter by KOHAI token mint
      { encoding: "jsonParsed" }        # Get parsed token account data
    ]
  }

  post(rpc_url, body)  # POST to Solana RPC endpoint
end
```

**Environment Variable Required:**
```bash
KOHAI_TOKEN_MINT=<Solana token mint address>
```

---

## Complete Flow Example

### Scenario: User Makes Purchase

```
1. User submits createOrder mutation with product ID

2. GraphQL resolver executes:
   app/graphql/mutations/orders/create_order.rb
   
3. Inside create_order.rb:
   
   a) Fetch fresh tier (force_refresh: true):
      tier_status = TierService.check_tier_status(current_user, force_refresh: true)
      
   b) TierService checks:
      - Is tier_checked_at > 5.minutes.ago? 
      - Since force_refresh: true, skip cache check
      
   c) Call blockchain:
      KohaiRpcService.get_tier(user.wallet_address)
        ↓
        KohaiRpcService.get_kohai_balance(wallet_address)
          ↓
          POST to Solana RPC: getTokenAccountsByOwner
          ↓
          Returns: 150,000 KOHAI
      
   d) Determine tier:
      balance = 150,000
      case 150_000
      when 50_000...500_000 → tier: :elite, discount: 1%
      
   e) Cache result:
      UPDATE users 
      SET tier = 'elite', kohai_balance = 150000.0, tier_checked_at = NOW
      WHERE id = user.id
      
   f) Calculate discounted price:
      original_price = 100 MYR
      discount_percent = 1%
      discount_amount = 1 MYR
      final_price = 99 MYR

4. Create order with:
   - amount: 99.00 (discounted)
   - tier_at_purchase: "Elite"
   - user_id, product_item_id, etc.

5. Return order to frontend with discount info

6. Within 5 minutes, any other tier check for this user returns cached data:
   tier_status = TierService.check_tier_status(current_user, force_refresh: false)
   → Returns cached: tier=elite, kohai_balance=150000.0 (no blockchain call)

7. After 5 minutes, next tier check fetches fresh data from blockchain again
```

---

## When Does Tier Update?

### Tier Updates Automatically When:

1. **User Makes Purchase** (force_refresh: true)
   - Always gets latest balance from blockchain
   - Caches for 5 minutes

2. **5+ Minutes Elapsed Since Last Check**
   - Next tier check fetches fresh balance
   - Updates cache if changed

3. **Force Refresh Triggered**
   - Can be called with `force_refresh: true` parameter
   - Bypasses cache, fetches immediately

### Tier Does NOT Update When:

- User hasn't made a purchase in 5 minutes
- User is just viewing products (no force_refresh)
- Cache is still valid (< 5 minutes old)

---

## Special Cases

### Case 1: User with No Tier

```ruby
user.tier # => nil
user.kohai_balance # => 0.0
user.tier_checked_at # => 2025-12-11 10:30:00

TierService.check_tier_status(user)
# => {
#      tier: :none,
#      discount_percent: 0,
#      badge: nil,
#      ...
#    }
```

### Case 2: User with Tier but Stale Cache

```ruby
user.tier # => "elite"
user.kohai_balance # => 50000.0
user.tier_checked_at # => 2025-12-11 09:30:00 (11 minutes ago)

TierService.check_tier_status(user, force_refresh: false)
# Cache expired → Fetch from blockchain
# Returns fresh balance and updates cache
```

### Case 3: User Tier Downgrade

```ruby
# User had 100,000 KOHAI (elite)
user.tier # => "elite"
user.kohai_balance # => 100000.0

# User sells 60,000 KOHAI (now has 40,000 - below elite threshold)
# Cache expires or force_refresh triggered

TierService.check_tier_status(user, force_refresh: true)
# Fetches balance: 40,000 KOHAI
# New tier: :none (0% discount)
# Updates: user.tier = nil, user.kohai_balance = 40000.0
```

---

## Performance Considerations

### Cache Benefits

```
Without cache (every request = blockchain call):
- 100 requests = 100 RPC calls
- 100 × 200ms (avg RPC latency) = 20 seconds total

With 5-minute cache:
- 100 requests within 5 min = 1 RPC call + 99 database reads
- 1 × 200ms + 99 × 5ms = 695ms total
- **28x faster**
```

### Blockchain Call Overhead

- Solana RPC call: ~200ms average
- Network latency: Region-dependent
- Timeout handling: Returns 0.0 balance if RPC fails

---

## Configuration

### Environment Variables

```bash
# .env or config/credentials.yml.enc
KOHAI_TOKEN_MINT=EKpQB2CdYVSsvkMZaxLDbtG4Z5TchZsUg9mUZtnvFc21  # Example
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
```

### Cache Duration

```ruby
# app/services/tier_service.rb line 19
user.tier_checked_at > 5.minutes.ago  # ← Can be tuned
```

---

## Logging

All tier updates are logged:

```ruby
# Cache hit
Rails.logger.info "Using cached tier for user #{user.id} (checked X minutes ago)"

# Cache miss
Rails.logger.info "Fetching fresh tier from blockchain for user #{user.id}"

# Cache update
user.update_columns(...)  # Success - no log

# Cache update failure
Rails.logger.warn "Failed to cache tier status for user #{user.id}: #{error}"

# Purchase with tier
Rails.logger.info "VIP_DISCOUNT tier=Legend discount=3% original=100.0 final=97.0"
```

---

## Testing

### Test Setup (Unit Tests)

```ruby
# Create user with cached tier (no blockchain call needed)
user = User.create!(
  wallet_address: "11111111111111111111111111111111",
  tier: "elite",                    # Cached tier
  kohai_balance: 50000.0,           # Cached balance
  tier_checked_at: 1.minute.ago     # Fresh cache
)

# Test will use cached tier, not blockchain
tier_info = TierService.check_tier_status(user, force_refresh: false)
assert_equal :elite, tier_info[:tier]
assert_equal 1, tier_info[:discount_percent]
```

---

## Summary

| Aspect | Details |
|--------|---------|
| **Update Trigger** | On-demand, during purchase or after 5-min cache expiry |
| **Cache Location** | User record (users.tier, users.kohai_balance, users.tier_checked_at) |
| **Cache Duration** | 5 minutes |
| **Blockchain Source** | Solana RPC - getTokenAccountsByOwner |
| **Data Point** | User's $KOHAI token balance |
| **Tier Thresholds** | 50k (Elite), 500k (Grandmaster), 3M (Legend) |
| **Force Refresh** | Always used during purchase to ensure latest discount |
| **Fallback** | Returns tier=:none, discount=0% if blockchain unavailable |

The system balances **real-time accuracy** (force refresh on purchase) with **performance** (5-minute cache for other operations).
