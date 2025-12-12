# GraphQL Queries for Frontend Integration

## Get Topup Products with Tier-Based Discounts

### Query: Get All Products

```graphql
query GetTopupProducts($category: ID, $page: Int, $perPage: Int) {
  topupProducts(categoryId: $category, page: $page, perPage: $perPage) {
    id
    title
    code
    category
    logoUrl
    avatarUrl
    topupProductItems {
      id
      name
      price
      currency
      icon
      
      # Tier-based pricing fields
      discountPercent      # User's discount: 0, 1, 2, or 3
      discountAmount       # Amount saved in original currency
      discountedPrice      # Final price after discount
      discountedPriceUsdt  # Discounted price in USDT
      tierInfo             # Complete tier information
    }
  }
}
```

**Variables:**
```json
{
  "category": "games",
  "page": 1,
  "perPage": 20
}
```

**Response Example (Legend Tier User):**
```json
{
  "data": {
    "topupProducts": [
      {
        "id": "1",
        "title": "Mobile Legends",
        "code": "mlbb",
        "category": "games",
        "logoUrl": "https://...",
        "avatarUrl": "https://...",
        "topupProductItems": [
          {
            "id": "item-1",
            "name": "500 Diamonds",
            "price": 10.0,
            "currency": "MYR",
            "icon": "https://...",
            "discountPercent": 3,
            "discountAmount": 0.30,
            "discountedPrice": 9.70,
            "discountedPriceUsdt": 2.18,
            "tierInfo": {
              "tier": "legend",
              "tierName": "Legend",
              "discountPercent": 3,
              "referralPercent": 3,
              "badge": "Legend",
              "style": "orange",
              "balance": 50000.0,
              "cached": true,
              "lastCheckedAt": "2025-12-10T10:30:00Z"
            }
          },
          {
            "id": "item-2",
            "name": "1000 Diamonds",
            "price": 19.99,
            "currency": "MYR",
            "icon": "https://...",
            "discountPercent": 3,
            "discountAmount": 0.60,
            "discountedPrice": 19.39,
            "discountedPriceUsdt": 4.36,
            "tierInfo": {
              "tier": "legend",
              "tierName": "Legend",
              "discountPercent": 3,
              "referralPercent": 3,
              "badge": "Legend",
              "style": "orange",
              "balance": 50000.0,
              "cached": true,
              "lastCheckedAt": "2025-12-10T10:30:00Z"
            }
          }
        ]
      }
    ]
  }
}
```

---

### Query: Get Single Product by ID

```graphql
query GetTopupProduct($id: ID!) {
  topupProduct(id: $id) {
    id
    title
    code
    description
    category
    logoUrl
    avatarUrl
    publisherLogo
    topupProductItems {
      id
      name
      price
      currency
      icon
      displayName
      formattedPrice
      
      # Tier-based pricing
      discountPercent
      discountAmount
      discountedPrice
      discountedPriceUsdt
      tierInfo
    }
  }
}
```

**Variables:**
```json
{
  "id": "1"
}
```

---

### Query: Get Single Product by Slug

```graphql
query GetTopupProductBySlug($slug: String!) {
  topupProduct(slug: $slug) {
    id
    title
    slug
    topupProductItems {
      id
      name
      price
      currency
      discountPercent
      discountAmount
      discountedPrice
      discountedPriceUsdt
      tierInfo
    }
  }
}
```

**Variables:**
```json
{
  "slug": "mobile-legends"
}
```

---

## Display Logic Examples

### React Component Example

```jsx
function TopupProductItem({ item }) {
  const { 
    name, 
    price, 
    currency,
    discountPercent, 
    discountAmount, 
    discountedPrice,
    tierInfo 
  } = item;

  return (
    <div className="product-item">
      <h3>{name}</h3>
      
      {/* Display pricing with discount */}
      <div className="pricing-section">
        {discountPercent > 0 ? (
          <>
            <span className="original-price">
              {price.toFixed(2)} {currency}
            </span>
            <span className="discount-badge">
              -{discountPercent}%
            </span>
            <span className="discounted-price">
              {discountedPrice.toFixed(2)} {currency}
            </span>
            <span className="savings">
              Save {discountAmount.toFixed(2)} {currency}
            </span>
          </>
        ) : (
          <span className="price">
            {price.toFixed(2)} {currency}
          </span>
        )}
      </div>

      {/* Display tier badge if user has discount */}
      {tierInfo && tierInfo.tier && (
        <div className={`tier-badge ${tierInfo.style}`}>
          <span className="tier-name">{tierInfo.badge}</span>
          <span className="tier-discount">+{tierInfo.discountPercent}%</span>
        </div>
      )}

      <button onClick={() => purchaseItem(item.id)}>
        {discountPercent > 0 ? 'Buy with Discount' : 'Buy Now'}
      </button>
    </div>
  );
}
```

### Vue Component Example

```vue
<template>
  <div class="product-item">
    <h3>{{ name }}</h3>
    
    <div class="pricing-section">
      <template v-if="discountPercent > 0">
        <span class="original-price">
          {{ price.toFixed(2) }} {{ currency }}
        </span>
        <span class="discount-badge">
          -{{ discountPercent }}%
        </span>
        <span class="discounted-price">
          {{ discountedPrice.toFixed(2) }} {{ currency }}
        </span>
        <span class="savings">
          Save {{ discountAmount.toFixed(2) }} {{ currency }}
        </span>
      </template>
      <template v-else>
        <span class="price">
          {{ price.toFixed(2) }} {{ currency }}
        </span>
      </template>
    </div>

    <div v-if="tierInfo && tierInfo.tier" :class="`tier-badge ${tierInfo.style}`">
      <span class="tier-name">{{ tierInfo.badge }}</span>
      <span class="tier-discount">+{{ tierInfo.discountPercent }}%</span>
    </div>

    <button @click="purchaseItem(item.id)">
      {{ discountPercent > 0 ? 'Buy with Discount' : 'Buy Now' }}
    </button>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  item: Object
})

const name = computed(() => props.item.name)
const price = computed(() => props.item.price)
const currency = computed(() => props.item.currency)
const discountPercent = computed(() => props.item.discountPercent)
const discountAmount = computed(() => props.item.discountAmount)
const discountedPrice = computed(() => props.item.discountedPrice)
const tierInfo = computed(() => props.item.tierInfo)

const purchaseItem = (itemId) => {
  // Handle purchase
}
</script>

<style scoped>
.product-item {
  border: 1px solid #ddd;
  padding: 1rem;
  border-radius: 8px;
}

.pricing-section {
  margin: 1rem 0;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.original-price {
  text-decoration: line-through;
  color: #999;
}

.discount-badge {
  background-color: #ff4444;
  color: white;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-weight: bold;
  font-size: 0.9rem;
}

.discounted-price {
  font-size: 1.2rem;
  font-weight: bold;
  color: #28a745;
}

.savings {
  font-size: 0.85rem;
  color: #666;
}

.tier-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  margin: 0.5rem 0;
}

.tier-badge.silver {
  background-color: #e8e8e8;
  color: #333;
  border: 2px solid #a0a0a0;
}

.tier-badge.gold {
  background: linear-gradient(135deg, #FFD700 0%, #FFA500 100%);
  color: #333;
  border: 2px solid #DAA520;
  box-shadow: 0 0 15px rgba(255, 215, 0, 0.4);
}

.tier-badge.orange {
  background-color: #FF6B35;
  color: white;
  border: 2px solid #FF6B35;
  box-shadow: 0 0 15px rgba(255, 107, 53, 0.6);
}

.tier-name {
  font-weight: bold;
}

.tier-discount {
  font-size: 0.9rem;
  opacity: 0.9;
}
</style>
```

---

## Usage Tips

### 1. Always Include tierInfo in Queries
The `tierInfo` field provides context about the user's tier and helps with styling.

### 2. Respect User Tiers
- Elite users see 1% discount
- Grandmaster users see 2% discount
- Legend users see 3% discount
- Non-tier users see 0% discount

### 3. Display Both Prices (When Discounted)
Show original and discounted price so users understand their savings.

### 4. Use Tier Colors
- Silver: Elite tier badge styling
- Gold: Grandmaster tier badge styling
- Orange: Legend tier badge styling

### 5. Handle Unauthenticated Users
When `tierInfo` is null, show no discount and no tier badge.

---

## Styling Reference

### CSS for Tier Badges

```css
.tier-badge.silver {
  background: linear-gradient(135deg, #C0C0C0 0%, #E8E8E8 100%);
  color: #333;
  border: 2px solid #A0A0A0;
}

.tier-badge.gold {
  background: linear-gradient(135deg, #FFD700 0%, #FFA500 100%);
  color: #333;
  border: 2px solid #DAA520;
  box-shadow: 0 0 15px rgba(255, 215, 0, 0.4);
}

.tier-badge.orange {
  background-color: #FF6B35;
  color: white;
  border: 2px solid #FF6B35;
  box-shadow: 0 0 15px rgba(255, 107, 53, 0.6);
}
```

---

## Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `discountPercent` | Integer | User's tier discount (0, 1, 2, or 3) |
| `discountAmount` | Float | Amount saved in original currency |
| `discountedPrice` | Float | Final price after discount in MYR |
| `discountedPriceUsdt` | Float | Final price after discount in USDT |
| `tierInfo` | JSON | Complete tier information (see below) |

### tierInfo Object

| Field | Type | Description |
|-------|------|-------------|
| `tier` | String | Tier identifier ("elite", "grandmaster", "legend", null) |
| `tierName` | String | Display name ("Elite", "Grandmaster", "Legend", null) |
| `discountPercent` | Integer | Discount percentage for this tier |
| `badge` | String | Badge text for display |
| `style` | String | CSS style key ("silver", "gold", "orange", null) |
| `balance` | Float | User's current $KOHAI balance |
| `cached` | Boolean | Whether tier info is from cache |
| `lastCheckedAt` | String | ISO timestamp of last tier check |

---

Ready to integrate! 🚀
