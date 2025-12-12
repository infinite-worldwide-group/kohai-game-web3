# Tier List Management System

## Overview

The Tier List Management System allows you to easily control and manage user tier configurations through a database table. Instead of hardcoding tier thresholds in environment variables, you can now update tiers directly through the database or GraphQL API.

---

## Database Schema

### Tiers Table

```sql
CREATE TABLE tiers (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  tier_key VARCHAR NOT NULL UNIQUE,
  minimum_balance DECIMAL(18,2) NOT NULL,
  discount_percent DECIMAL(5,2) DEFAULT 0,
  badge_name VARCHAR,
  badge_color VARCHAR,
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  description TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Indexes for performance
CREATE INDEX index_tiers_on_tier_key UNIQUE;
CREATE INDEX index_tiers_on_display_order;
CREATE INDEX index_tiers_on_is_active;
CREATE INDEX index_tiers_on_minimum_balance;
```

### Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | BIGINT | Primary key | - |
| `name` | STRING | Display name for tier | "Elite", "Grandmaster", "Legend" |
| `tier_key` | STRING | Unique identifier | "elite", "grandmaster", "legend" |
| `minimum_balance` | DECIMAL | Min KOHAI tokens required | 5000, 50000, 300000 |
| `discount_percent` | DECIMAL | Discount percentage | 1, 2, 3 |
| `badge_name` | STRING | Badge display name | "Elite", "Grandmaster" |
| `badge_color` | STRING | Badge color | "silver", "gold", "orange" |
| `display_order` | INTEGER | Order for listing | 1, 2, 3 |
| `is_active` | BOOLEAN | Whether tier is active | true/false |
| `description` | TEXT | Tier benefits description | "Premium VIP tier..." |
| `metadata` | JSONB | Additional data | {} |

---

## Model: Tier

Located at `app/models/tier.rb`

### Scopes

```ruby
Tier.active                    # Get all active tiers
Tier.by_order                  # Order by display_order ASC
Tier.by_balance_requirement    # Order by minimum_balance DESC (most restrictive first)
```

### Class Methods

```ruby
# Get tier for a specific balance
Tier.get_tier_for_balance(14441)  # Returns tier or tier_none

# Get all tier keys
Tier.tier_keys  # => ["elite", "grandmaster", "legend"]

# Get specific tier by key
Tier.tier_by_key("elite")  # => Tier object

# Get nil-like tier (for users with no tier)
Tier.tier_none  # => OpenStruct with default none tier
```

### Instance Methods

```ruby
tier = Tier.find(1)

# Human-readable display name
tier.display_name  # => "Elite (5,000 tokens)"

# Badge information
tier.badge_info  # => { name: "Elite", color: "silver" }

# Full tier benefits
tier.tier_benefits  
# => { name: "Elite", tier_key: "elite", minimum_balance: 5000, 
#      discount_percent: 1, badge: {...}, description: "..." }
```

---

## Backend Integration

### Service: KohaiRpcService

Updated to use database tiers with ENV variable fallback:

```ruby
# Get current tier thresholds from database
KohaiRpcService.tier_thresholds
# => { elite: 5000, grandmaster: 50000, legend: 300000 }

# Get specific threshold
KohaiRpcService.elite_min      # => 5000
KohaiRpcService.grandmaster_min # => 50000
KohaiRpcService.legend_min      # => 300000

# Get user tier based on balance
KohaiRpcService.get_tier("DFR4gji369NG96p2u4cLqXLY6nNwTjxsRVKm4LbbE9v8")
# => { tier: :elite, tier_name: "Elite", discount_percent: 1, ... }
```

#### Fallback Behavior

If the database is unavailable or table doesn't exist, the service falls back to environment variables:

```bash
KOHAI_ELITE_MIN=5000
KOHAI_GRANDMASTER_MIN=50000
KOHAI_LEGEND_MIN=300000
```

---

## GraphQL API

### Queries

#### 1. Get All Tiers

```graphql
query {
  tiers(sortBy: "order", includeInactive: false) {
    id
    name
    tierKey
    minimumBalance
    discountPercent
    badgeName
    badgeColor
    displayOrder
    isActive
    description
    displayName
    tierBenefits {
      name
      tierKey
      minimumBalance
      discountPercent
      badge {
        name
        color
      }
    }
  }
}
```

**Arguments:**
- `sortBy`: "order" | "balance" | "discount" (default: "order")
- `includeInactive`: Boolean (default: false)

**Response:**
```json
{
  "data": {
    "tiers": [
      {
        "id": "1",
        "name": "Elite",
        "tierKey": "elite",
        "minimumBalance": "5000",
        "discountPercent": "1.0",
        "badgeName": "Elite",
        "badgeColor": "silver",
        "displayOrder": 1,
        "isActive": true,
        "description": "Entry-level VIP tier with 1% discount",
        "displayName": "Elite (5,000 tokens)",
        "tierBenefits": { ... }
      },
      ...
    ]
  }
}
```

#### 2. Get Tier by Key

```graphql
query {
  tierByKey(tierKey: "elite") {
    id
    name
    tierKey
    minimumBalance
    discountPercent
    badgeName
    badgeColor
    description
  }
}
```

**Response:**
```json
{
  "data": {
    "tierByKey": {
      "id": "1",
      "name": "Elite",
      "tierKey": "elite",
      "minimumBalance": "5000",
      "discountPercent": "1.0",
      "badgeName": "Elite",
      "badgeColor": "silver",
      "description": "Entry-level VIP tier with 1% discount"
    }
  }
}
```

---

### Mutations

#### 1. Create Tier

```graphql
mutation {
  createTier(
    name: "VIP"
    tierKey: "vip"
    minimumBalance: "100000"
    discountPercent: "5"
    badgeName: "VIP"
    badgeColor: "platinum"
    description: "Exclusive VIP tier"
    displayOrder: 4
  ) {
    tier {
      id
      name
      tierKey
      minimumBalance
      discountPercent
    }
    errors
  }
}
```

**Response:**
```json
{
  "data": {
    "createTier": {
      "tier": {
        "id": "4",
        "name": "VIP",
        "tierKey": "vip",
        "minimumBalance": "100000",
        "discountPercent": "5.0"
      },
      "errors": []
    }
  }
}
```

#### 2. Update Tier

```graphql
mutation {
  updateTier(
    id: "1"
    name: "Elite Plus"
    minimumBalance: "7500"
    discountPercent: "1.5"
    badgeColor: "platinum"
  ) {
    tier {
      id
      name
      minimumBalance
      discountPercent
    }
    errors
  }
}
```

**Response:**
```json
{
  "data": {
    "updateTier": {
      "tier": {
        "id": "1",
        "name": "Elite Plus",
        "minimumBalance": "7500",
        "discountPercent": "1.5"
      },
      "errors": []
    }
  }
}
```

#### 3. Delete Tier

```graphql
mutation {
  deleteTier(id: "4") {
    success
    message
    errors
  }
}
```

**Response:**
```json
{
  "data": {
    "deleteTier": {
      "success": true,
      "message": "Tier deleted successfully",
      "errors": []
    }
  }
}
```

---

## Usage Examples

### Rails Console

#### Create a New Tier

```ruby
tier = Tier.create(
  name: "Platinum",
  tier_key: "platinum",
  minimum_balance: 1000000,
  discount_percent: 5,
  badge_name: "Platinum",
  badge_color: "platinum",
  display_order: 4,
  description: "Ultimate VIP tier"
)
# => #<Tier id: 4, name: "Platinum", ...>
```

#### Update a Tier

```ruby
tier = Tier.find_by(tier_key: "elite")
tier.update(discount_percent: 1.5, description: "Updated Elite tier benefits")
# => true
```

#### Get Tier for User Balance

```ruby
balance = 75000  # User has 75k KOHAI tokens
tier = Tier.get_tier_for_balance(balance)  # => Grandmaster tier

puts "User is: #{tier.name}"  # => User is: Grandmaster
puts "Discount: #{tier.discount_percent}%"  # => Discount: 2%
```

#### List All Active Tiers

```ruby
Tier.active.by_order.each do |tier|
  puts "#{tier.name}: #{tier.minimum_balance} tokens → #{tier.discount_percent}% discount"
end

# Output:
# Elite: 5000 tokens → 1% discount
# Grandmaster: 50000 tokens → 2% discount
# Legend: 300000 tokens → 3% discount
```

#### Deactivate a Tier

```ruby
tier = Tier.find_by(tier_key: "elite")
tier.update(is_active: false)
# => true
```

#### Get Tier Thresholds

```ruby
KohaiRpcService.tier_thresholds
# => { elite: 5000, grandmaster: 50000, legend: 300000 }
```

---

## Setup Instructions

### 1. Run Migration

```bash
rails db:migrate
```

This creates the `tiers` table with all necessary fields and indexes.

### 2. Seed Initial Data

```bash
rails db:seed
```

This creates three default tiers:
- Elite (5,000 tokens, 1% discount)
- Grandmaster (50,000 tokens, 2% discount)
- Legend (300,000 tokens, 3% discount)

Or manually seed:

```ruby
rails console
Tier.create!(
  name: "Elite",
  tier_key: "elite",
  minimum_balance: 5000,
  discount_percent: 1,
  badge_name: "Elite",
  badge_color: "silver",
  display_order: 1,
  is_active: true
)
```

### 3. Start Using the API

Use the GraphQL queries and mutations to manage tiers:

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "query { tiers(sortBy: \"order\") { id name minimumBalance discountPercent } }"}'
```

---

## Key Features

✅ **Centralized Management** - All tier configurations in one database table  
✅ **Easy Updates** - Change thresholds and discounts without redeploying  
✅ **GraphQL API** - Create, read, update, delete tiers via API  
✅ **Backward Compatible** - Falls back to ENV variables if database unavailable  
✅ **Flexible Sorting** - Sort by order, balance requirement, or discount  
✅ **Active/Inactive** - Soft delete tiers by setting is_active to false  
✅ **Metadata Support** - Store additional tier data in JSONB field  
✅ **Indexed** - Optimized queries with proper database indexes  

---

## Migration Guide (From ENV Variables)

If you're currently using environment variables:

1. **Keep ENV variables** - They're still supported as fallback
2. **Create tiers in database** - Run seeds or manually create
3. **Verify in GraphQL** - Test with `{ tiers { id name } }`
4. **Update tier values** - Via Rails console or GraphQL mutations
5. **Monitor tier assignments** - Check `Tier.get_tier_for_balance(balance)`

Example transition:

```bash
# Before: Using ENV variables
export KOHAI_ELITE_MIN=5000
export KOHAI_GRANDMASTER_MIN=50000
export KOHAI_LEGEND_MIN=300000

# After: Using database (ENV as fallback)
rails console
Tier.create!(name: "Elite", tier_key: "elite", minimum_balance: 5000, ...)
KohaiRpcService.tier_thresholds  # Reads from database now
```

---

## Performance Considerations

### Indexes

The migration creates indexes on:
- `tier_key` (UNIQUE) - Fast lookup by key
- `display_order` - Fast ordering
- `is_active` - Fast filtering
- `minimum_balance` - Fast range queries

### Caching

The tier thresholds are fetched from the database each time. For high-frequency usage, consider caching:

```ruby
# Add to KohaiRpcService
def self.tier_thresholds
  Rails.cache.fetch("tier_thresholds", expires_in: 1.hour) do
    # Load from database or ENV
  end
end

# Invalidate cache when tiers update
# In Tier model:
after_save :invalidate_tier_cache

def invalidate_tier_cache
  Rails.cache.delete("tier_thresholds")
end
```

---

## API Documentation Summary

| Operation | GraphQL | Rails | HTTP |
|-----------|---------|-------|------|
| List all | `query { tiers }` | `Tier.all` | GET /graphql |
| Get by key | `query { tierByKey }` | `Tier.tier_by_key` | GET /graphql |
| Create | `mutation { createTier }` | `Tier.create!` | POST /graphql |
| Update | `mutation { updateTier }` | `tier.update` | POST /graphql |
| Delete | `mutation { deleteTier }` | `tier.update(is_active: false)` | POST /graphql |

---

## Troubleshooting

### Tier Not Found

```ruby
# Check if tier exists
Tier.where(tier_key: "elite").exists?  # => true

# Check if tier is active
Tier.active.where(tier_key: "elite").exists?  # => true
```

### User Getting Wrong Tier

```ruby
# Debug tier assignment
balance = 75000
tier = Tier.get_tier_for_balance(balance)
puts "Balance: #{balance}, Tier: #{tier.name}"

# Check all tiers
Tier.active.by_balance_requirement.each { |t| puts "#{t.name}: #{t.minimum_balance}" }
```

### Database Not Available (Fallback Mode)

```ruby
# Service automatically falls back to ENV variables
KohaiRpcService.tier_thresholds  # Uses ENV if table doesn't exist

# Check which mode is active
Tier.table_exists?  # => true (using DB) or false (using ENV)
```

---

## Next Steps

1. ✅ Run migration: `rails db:migrate`
2. ✅ Seed data: `rails db:seed`
3. ✅ Test GraphQL queries
4. ✅ Update frontend to fetch tiers via API
5. ✅ Monitor tier assignments in production
