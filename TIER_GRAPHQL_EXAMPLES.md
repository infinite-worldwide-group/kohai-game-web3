# Tier List Management - GraphQL Examples

## Base URL
```
http://localhost:3000/graphql
```

---

## Queries

### 1. Get All Tiers (Sorted by Display Order)

**Request:**
```graphql
query GetAllTiers {
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
      description
    }
    createdAt
    updatedAt
  }
}
```

**Expected Response:**
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
        "description": "Entry-level VIP tier with 1% discount on all game credits",
        "displayName": "Elite (5,000 tokens)",
        "tierBenefits": {
          "name": "Elite",
          "tierKey": "elite",
          "minimumBalance": "5000",
          "discountPercent": "1.0",
          "badge": {
            "name": "Elite",
            "color": "silver"
          },
          "description": "Entry-level VIP tier with 1% discount on all game credits"
        },
        "createdAt": "2025-12-11T15:50:56Z",
        "updatedAt": "2025-12-11T15:50:56Z"
      },
      {
        "id": "2",
        "name": "Grandmaster",
        "tierKey": "grandmaster",
        "minimumBalance": "50000",
        "discountPercent": "2.0",
        "badgeName": "Grandmaster",
        "badgeColor": "gold",
        "displayOrder": 2,
        "isActive": true,
        "description": "Mid-level VIP tier with 2% discount on all game credits",
        "displayName": "Grandmaster (50,000 tokens)",
        "tierBenefits": { ... },
        "createdAt": "2025-12-11T15:50:56Z",
        "updatedAt": "2025-12-11T15:50:56Z"
      },
      {
        "id": "3",
        "name": "Legend",
        "tierKey": "legend",
        "minimumBalance": "300000",
        "discountPercent": "3.0",
        "badgeName": "Legend",
        "badgeColor": "orange",
        "displayOrder": 3,
        "isActive": true,
        "description": "Premium VIP tier with 3% discount on all game credits",
        "displayName": "Legend (300,000 tokens)",
        "tierBenefits": { ... },
        "createdAt": "2025-12-11T15:50:56Z",
        "updatedAt": "2025-12-11T15:50:56Z"
      }
    ]
  }
}
```

---

### 2. Get Tiers Sorted by Balance Requirement (Most Restrictive First)

**Request:**
```graphql
query GetTiersByBalance {
  tiers(sortBy: "balance", includeInactive: false) {
    id
    name
    tierKey
    minimumBalance
    discountPercent
  }
}
```

**Response:**
```json
{
  "data": {
    "tiers": [
      {
        "id": "3",
        "name": "Legend",
        "tierKey": "legend",
        "minimumBalance": "300000",
        "discountPercent": "3.0"
      },
      {
        "id": "2",
        "name": "Grandmaster",
        "tierKey": "grandmaster",
        "minimumBalance": "50000",
        "discountPercent": "2.0"
      },
      {
        "id": "1",
        "name": "Elite",
        "tierKey": "elite",
        "minimumBalance": "5000",
        "discountPercent": "1.0"
      }
    ]
  }
}
```

---

### 3. Get Tiers Sorted by Discount (Highest First)

**Request:**
```graphql
query GetTiersByDiscount {
  tiers(sortBy: "discount", includeInactive: false) {
    id
    name
    discountPercent
    badgeColor
  }
}
```

---

### 4. Get All Tiers (Including Inactive)

**Request:**
```graphql
query GetAllTiersIncludingInactive {
  tiers(sortBy: "order", includeInactive: true) {
    id
    name
    isActive
    discountPercent
  }
}
```

---

### 5. Get Specific Tier by Key

**Request:**
```graphql
query GetEliteTier {
  tierByKey(tierKey: "elite") {
    id
    name
    tierKey
    minimumBalance
    discountPercent
    badgeName
    badgeColor
    description
    displayName
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
      "description": "Entry-level VIP tier with 1% discount on all game credits",
      "displayName": "Elite (5,000 tokens)"
    }
  }
}
```

---

## Mutations

### 1. Create New Tier

**Request:**
```graphql
mutation CreateVIPTier {
  createTier(
    name: "VIP"
    tierKey: "vip"
    minimumBalance: "1000000"
    discountPercent: "4"
    badgeName: "VIP"
    badgeColor: "platinum"
    description: "Exclusive VIP tier with 4% discount and special perks"
    displayOrder: 4
  ) {
    tier {
      id
      name
      tierKey
      minimumBalance
      discountPercent
      badgeName
      badgeColor
      displayOrder
    }
    errors
  }
}
```

**Response (Success):**
```json
{
  "data": {
    "createTier": {
      "tier": {
        "id": "4",
        "name": "VIP",
        "tierKey": "vip",
        "minimumBalance": "1000000",
        "discountPercent": "4.0",
        "badgeName": "VIP",
        "badgeColor": "platinum",
        "displayOrder": 4
      },
      "errors": []
    }
  }
}
```

**Response (Error - Duplicate tierKey):**
```json
{
  "data": {
    "createTier": {
      "tier": null,
      "errors": [
        "Tier key has already been taken"
      ]
    }
  }
}
```

---

### 2. Update Tier Discount

**Request:**
```graphql
mutation UpdateEliteDiscount {
  updateTier(
    id: "1"
    discountPercent: "1.5"
    description: "Elite tier - updated with 1.5% discount"
  ) {
    tier {
      id
      name
      discountPercent
      description
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
        "name": "Elite",
        "discountPercent": "1.5",
        "description": "Elite tier - updated with 1.5% discount"
      },
      "errors": []
    }
  }
}
```

---

### 3. Update Multiple Tier Fields

**Request:**
```graphql
mutation UpdateGrandmasterTier {
  updateTier(
    id: "2"
    name: "Grandmaster Pro"
    minimumBalance: "75000"
    discountPercent: "2.5"
    badgeColor: "gold-platinum"
    displayOrder: 2
  ) {
    tier {
      id
      name
      minimumBalance
      discountPercent
      badgeColor
    }
    errors
  }
}
```

---

### 4. Update Tier by Key

**Request (Using Tier Key to Find):**
```graphql
mutation UpdateLegendTier {
  updateTier(
    id: "3"
    name: "Legendary"
    discountPercent: "3.5"
    badgeColor: "golden-orange"
  ) {
    tier {
      id
      name
      tierKey
      discountPercent
    }
    errors
  }
}
```

---

### 5. Deactivate Tier (Soft Delete)

**Request:**
```graphql
mutation DeactivateTier {
  updateTier(
    id: "4"
    isActive: false
  ) {
    tier {
      id
      name
      isActive
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
        "id": "4",
        "name": "VIP",
        "isActive": false
      },
      "errors": []
    }
  }
}
```

---

### 6. Delete Tier (Set Inactive)

**Request:**
```graphql
mutation DeleteVIPTier {
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

### 7. Delete Non-Existent Tier

**Request:**
```graphql
mutation DeleteNonExistent {
  deleteTier(id: "999") {
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
      "success": false,
      "message": "Tier not found",
      "errors": [
        "Tier not found"
      ]
    }
  }
}
```

---

## Batch Operations

### Add Multiple New Tiers

**Request:**
```graphql
mutation AddMultipleTiers {
  tier1: createTier(
    name: "Gold"
    tierKey: "gold"
    minimumBalance: "250000"
    discountPercent: "2.5"
    badgeName: "Gold"
    badgeColor: "gold"
    displayOrder: 4
  ) {
    tier { id name }
    errors
  }

  tier2: createTier(
    name: "Platinum"
    tierKey: "platinum"
    minimumBalance: "500000"
    discountPercent: "3.5"
    badgeName: "Platinum"
    badgeColor: "platinum"
    displayOrder: 5
  ) {
    tier { id name }
    errors
  }

  tier3: createTier(
    name: "Diamond"
    tierKey: "diamond"
    minimumBalance: "1000000"
    discountPercent: "5"
    badgeName: "Diamond"
    badgeColor: "cyan"
    displayOrder: 6
  ) {
    tier { id name }
    errors
  }
}
```

---

### Update Multiple Tiers

**Request:**
```graphql
mutation UpdateMultipleTiers {
  elite: updateTier(id: "1", discountPercent: "1.2") {
    tier { discountPercent }
  }

  grandmaster: updateTier(id: "2", discountPercent: "2.2") {
    tier { discountPercent }
  }

  legend: updateTier(id: "3", discountPercent: "3.2") {
    tier { discountPercent }
  }
}
```

---

## Using with Curl

### Query All Tiers

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { tiers(sortBy: \"order\") { id name minimumBalance discountPercent } }"
  }'
```

### Create New Tier

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createTier(name: \"VIP\", tierKey: \"vip\", minimumBalance: \"1000000\", discountPercent: \"4\") { tier { id name } errors } }"
  }'
```

### Update Tier

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { updateTier(id: \"1\", discountPercent: \"1.5\") { tier { id discountPercent } } }"
  }'
```

---

## Common GraphQL Variables

Instead of hardcoding values, use variables:

**Request with Variables:**
```graphql
mutation CreateTierWithVars($name: String!, $key: String!, $min: BigInt!, $discount: Decimal!) {
  createTier(
    name: $name
    tierKey: $key
    minimumBalance: $min
    discountPercent: $discount
  ) {
    tier { id name }
    errors
  }
}
```

**Variables:**
```json
{
  "name": "Super VIP",
  "key": "super_vip",
  "min": "2000000",
  "discount": "5"
}
```

---

## Error Handling Examples

### Validation Error

**Request (Invalid discount):**
```graphql
mutation InvalidDiscount {
  createTier(
    name: "Test"
    tierKey: "test"
    minimumBalance: "1000"
    discountPercent: "150"  # Invalid: > 100
  ) {
    tier { id }
    errors
  }
}
```

**Response:**
```json
{
  "data": {
    "createTier": {
      "tier": null,
      "errors": [
        "Discount percent must be less than or equal to 100"
      ]
    }
  }
}
```

---

### Duplicate Key Error

**Request (Duplicate tierKey):**
```graphql
mutation DuplicateKey {
  createTier(
    name: "Elite Plus"
    tierKey: "elite"  # Already exists
    minimumBalance: "10000"
    discountPercent: "2"
  ) {
    tier { id }
    errors
  }
}
```

**Response:**
```json
{
  "data": {
    "createTier": {
      "tier": null,
      "errors": [
        "Tier key has already been taken"
      ]
    }
  }
}
```

---

## Tips & Tricks

### Copy from GraphQL Playground

```graphql
# Go to: http://localhost:3000/graphql
# Write and test queries/mutations
# Use introspection to see all fields
```

### Format Decimal Values

```graphql
# Decimals must be quoted strings or numbers
discountPercent: "1.5"    # ✓ Works
discountPercent: 1.5      # ✓ Works
minimumBalance: "5000"    # ✓ Works
minimumBalance: 5000      # ✓ Works
```

### Check Current Tier Thresholds

```bash
rails console
> KohaiRpcService.tier_thresholds
```

---

## Testing Checklist

- [ ] Query all tiers
- [ ] Query tier by key
- [ ] Create new tier
- [ ] Update tier discount
- [ ] Update multiple fields
- [ ] Deactivate tier
- [ ] Delete tier
- [ ] Error handling - duplicate key
- [ ] Error handling - validation
- [ ] Batch operations

