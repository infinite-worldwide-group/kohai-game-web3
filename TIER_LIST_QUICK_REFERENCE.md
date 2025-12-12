# Tier List Management - Quick Reference

## 30-Second Setup

```bash
# 1. Run migration
rails db:migrate

# 2. Seed default tiers
rails db:seed

# Done! Tiers are ready to use
```

---

## 5 Ways to Manage Tiers

### 1. Rails Console (Quick Edit)

```ruby
rails console

# Create tier
Tier.create(name: "VIP", tier_key: "vip", minimum_balance: 100000, discount_percent: 5)

# Update tier
Tier.find(1).update(discount_percent: 1.5)

# View all tiers
Tier.active.by_order.each { |t| puts "#{t.name}: #{t.minimum_balance}" }

# Delete tier (soft delete)
Tier.find(1).update(is_active: false)
```

### 2. GraphQL Query

```graphql
query GetAllTiers {
  tiers(sortBy: "order") {
    id name tierKey minimumBalance discountPercent badgeName
  }
}
```

### 3. GraphQL Mutation (Create)

```graphql
mutation CreateNewTier {
  createTier(
    name: "Platinum"
    tierKey: "platinum"
    minimumBalance: "500000"
    discountPercent: "4"
    badgeName: "Platinum"
    badgeColor: "platinum"
  ) {
    tier { id name minimumBalance }
    errors
  }
}
```

### 4. GraphQL Mutation (Update)

```graphql
mutation UpdateTier {
  updateTier(
    id: "1"
    discountPercent: "2"
    description: "Updated Elite benefits"
  ) {
    tier { id name discountPercent }
    errors
  }
}
```

### 5. GraphQL Mutation (Delete)

```graphql
mutation DeleteTier {
  deleteTier(id: "1") {
    success message
  }
}
```

---

## Key Commands

| Action | Command |
|--------|---------|
| **List all tiers** | `rails c` → `Tier.active.by_order` |
| **Get tier for balance** | `Tier.get_tier_for_balance(75000)` |
| **Find by key** | `Tier.tier_by_key("elite")` |
| **Update discount** | `Tier.find(1).update(discount_percent: 1.5)` |
| **Check tier thresholds** | `KohaiRpcService.tier_thresholds` |
| **Deactivate tier** | `Tier.find(1).update(is_active: false)` |

---

## Default Tiers (After Seeding)

```
┌─────────────┬─────────────┬──────────┬──────────┐
│ Name        │ Min Balance │ Discount │ Color    │
├─────────────┼─────────────┼──────────┼──────────┤
│ Elite       │ 5,000       │ 1%       │ Silver   │
│ Grandmaster │ 50,000      │ 2%       │ Gold     │
│ Legend      │ 300,000     │ 3%       │ Orange   │
└─────────────┴─────────────┴──────────┴──────────┘
```

---

## GraphQL Cheat Sheet

### Query All Tiers

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
  }
}
```

### Query Single Tier by Key

```graphql
query {
  tierByKey(tierKey: "elite") {
    name
    minimumBalance
    discountPercent
    description
  }
}
```

### Create Tier

```graphql
mutation {
  createTier(
    name: "String!"
    tierKey: "String!"
    minimumBalance: "BigInt!"
    discountPercent: "Decimal!"
    badgeName: "String"
    badgeColor: "String"
    description: "String"
    displayOrder: "Int"
  ) {
    tier { id name }
    errors
  }
}
```

### Update Tier

```graphql
mutation {
  updateTier(
    id: "ID!"
    name: "String"
    minimumBalance: "BigInt"
    discountPercent: "Decimal"
    badgeName: "String"
    badgeColor: "String"
    description: "String"
    displayOrder: "Int"
    isActive: "Boolean"
  ) {
    tier { id name }
    errors
  }
}
```

### Delete Tier

```graphql
mutation {
  deleteTier(id: "ID!") {
    success
    message
    errors
  }
}
```

---

## Common Tasks

### Change Elite Minimum to 8,000 Tokens

```ruby
# Rails console
Tier.tier_by_key("elite").update(minimum_balance: 8000)

# GraphQL
mutation {
  updateTier(id: "1", minimumBalance: "8000") {
    tier { minimumBalance }
  }
}
```

### Add New VIP Tier at 2 Million Tokens

```ruby
# Rails console
Tier.create!(
  name: "VIP",
  tier_key: "vip",
  minimum_balance: 2000000,
  discount_percent: 4,
  badge_name: "VIP",
  badge_color: "platinum",
  display_order: 4,
  description: "Exclusive VIP tier"
)
```

### Get User Tier for 100,000 Tokens

```ruby
tier = Tier.get_tier_for_balance(100000)
# => Grandmaster tier

puts "#{tier.name}: #{tier.discount_percent}% discount"
# => Grandmaster: 2% discount
```

### List All Tier Thresholds

```ruby
KohaiRpcService.tier_thresholds
# => { elite: 5000, grandmaster: 50000, legend: 300000 }
```

### Check Database vs ENV Fallback

```ruby
# If table exists, uses database
# If table missing, uses ENV variables
Tier.table_exists?  # => true (using DB) or false (using ENV)

# Verify which config is active
KohaiRpcService.elite_min
```

---

## Testing Tier Changes

### Test Tier Assignment

```ruby
rails console

# Test different balances
test_balances = [1000, 5000, 25000, 50000, 100000, 300000, 500000]

test_balances.each do |balance|
  tier = Tier.get_tier_for_balance(balance)
  puts "#{balance.to_s.rjust(7)} tokens → #{tier.name.ljust(15)}: #{tier.discount_percent}% discount"
end

# Output:
#    1000 tokens → None             : 0% discount
#    5000 tokens → Elite            : 1% discount
#   25000 tokens → Elite            : 1% discount
#   50000 tokens → Grandmaster      : 2% discount
#  100000 tokens → Grandmaster      : 2% discount
#  300000 tokens → Legend           : 3% discount
#  500000 tokens → Legend           : 3% discount
```

### Verify GraphQL API

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { tiers(sortBy: \"order\") { name minimumBalance discountPercent } }"
  }'
```

---

## Database Operations

### View Tier Table

```ruby
# Rails console
Tier.pluck(:name, :minimum_balance, :discount_percent, :is_active)

# Output:
# [["Elite", 5000, 1, true],
#  ["Grandmaster", 50000, 2, true],
#  ["Legend", 300000, 3, true]]
```

### Export Tiers to CSV

```ruby
require 'csv'

CSV.open("tiers.csv", "w") do |csv|
  csv << ["Name", "Tier Key", "Min Balance", "Discount %", "Badge", "Color"]
  Tier.active.by_order.each do |tier|
    csv << [tier.name, tier.tier_key, tier.minimum_balance, tier.discount_percent, tier.badge_name, tier.badge_color]
  end
end
```

### Backup/Restore Tiers

```ruby
# Backup (Rails console)
backup = Tier.all.map(&:attributes)
File.write("tiers_backup.json", JSON.pretty_generate(backup))

# Restore
data = JSON.parse(File.read("tiers_backup.json"))
Tier.delete_all
data.each { |attrs| Tier.create!(attrs.except("id", "created_at", "updated_at")) }
```

---

## Fallback to Environment Variables

If database is unavailable, the system automatically uses:

```bash
KOHAI_ELITE_MIN=5000
KOHAI_GRANDMASTER_MIN=50000
KOHAI_LEGEND_MIN=300000
```

---

## Files Created/Modified

| File | Purpose |
|------|---------|
| `db/migrate/20251211155056_create_tiers.rb` | Database migration |
| `app/models/tier.rb` | Tier model & scopes |
| `app/services/kohai_rpc_service.rb` | Updated to use DB tiers |
| `app/graphql/types/tier_type.rb` | GraphQL type |
| `app/graphql/queries/tiers.rb` | List tiers query |
| `app/graphql/queries/tier_by_key.rb` | Get tier query |
| `app/graphql/mutations/create_tier.rb` | Create mutation |
| `app/graphql/mutations/update_tier.rb` | Update mutation |
| `app/graphql/mutations/delete_tier.rb` | Delete mutation |
| `db/seeds/tiers.rb` | Seed data |

---

## Next Steps

1. ✅ Run: `rails db:migrate`
2. ✅ Run: `rails db:seed`
3. ✅ Test: Query `{ tiers { id name } }` in GraphQL
4. ✅ Update: Change tier values as needed
5. ✅ Deploy: Push to production

---

**That's it!** You now have a fully manageable tier system.
