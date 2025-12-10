# Frontend Integration Guide: VIP Tier Discount System

## Overview

The backend now supports VIP tier discounts based on $KOHAI token holdings. This guide explains how to integrate tier information and styling into the frontend.

## Tier Levels

| Tier | KOHAI Holdings | Discount | Badge | Style Color |
|------|----------------|----------|-------|-------------|
| **Elite** | 50,000 - 499,999 | 1% | "Elite" | `silver` |
| **Grandmaster** | 500,000 - 2,999,999 | 2% | "Grandmaster" | `gold` |
| **Legend** | 3,000,000+ | 3% | "Legend" | `orange` |
| None | Below 50,000 | 0% | null | null |

---

## GraphQL API

### 1. Get Current User with Tier Info

**Query:**
```graphql
query GetCurrentUser {
  currentUser {
    id
    walletAddress
    email

    # VIP Tier fields
    tier              # "elite", "grandmaster", "legend", or null
    tierName          # "Elite", "Grandmaster", "Legend", or null
    discountPercent   # 0, 1, 2, or 3
    kohaiBalance      # Current token balance (e.g., 150000.5)
    tierBadge         # Display name for badge (same as tierName)
    tierStyle         # "silver", "gold", "orange", or null
  }
}
```

**Example Response:**
```json
{
  "data": {
    "currentUser": {
      "id": "123",
      "walletAddress": "7xK2...",
      "email": "user@example.com",
      "tier": "legend",
      "tierName": "Legend",
      "discountPercent": 3,
      "kohaiBalance": 5000000.0,
      "tierBadge": "Legend",
      "tierStyle": "orange"
    }
  }
}
```

**Note:** This uses a 5-minute cached tier status to avoid blockchain RPC calls on every page load.

---

### 2. Get Tier Status with Real-Time Check

**Query (Cached - Default):**
```graphql
query GetTierStatus {
  tierStatus {
    tier              # "elite", "grandmaster", "legend", or null
    tierName          # Display name
    discountPercent   # 0-3
    referralPercent   # Future feature (currently same as discount)
    badge             # Badge display text
    style             # "silver", "gold", "orange", or null
    balance           # Current $KOHAI balance
    cached            # true if from cache, false if fresh
    lastCheckedAt     # ISO8601 timestamp of last check
  }
}
```

**Query (Force Real-Time Check):**
```graphql
query GetTierStatusRealtime {
  tierStatus(forceRefresh: true) {
    tier
    tierName
    discountPercent
    balance
    style
    cached            # Will be false
    lastCheckedAt
  }
}
```

**Example Response (Legend Tier):**
```json
{
  "data": {
    "tierStatus": {
      "tier": "legend",
      "tierName": "Legend",
      "discountPercent": 3,
      "referralPercent": 3,
      "badge": "Legend",
      "style": "orange",
      "balance": 5000000.0,
      "cached": false,
      "lastCheckedAt": "2025-12-10T10:30:00Z"
    }
  }
}
```

**Example Response (No Tier):**
```json
{
  "data": {
    "tierStatus": {
      "tier": null,
      "tierName": null,
      "discountPercent": 0,
      "referralPercent": 0,
      "badge": null,
      "style": null,
      "balance": 1000.0,
      "cached": false,
      "lastCheckedAt": "2025-12-10T10:30:00Z"
    }
  }
}
```

---

### 3. Create Order with Discount Applied

**Mutation:**
```graphql
mutation CreateOrder {
  createOrder(
    topupProductItemId: "123"
    transactionSignature: "5x7K..."
    cryptoCurrency: "USDT"
    gameAccountId: "456"
  ) {
    order {
      id
      orderNumber
      amount              # Final price after discount (e.g., 0.0388)
      originalAmount      # Original price before discount (e.g., 0.04)
      discountAmount      # Discount amount (e.g., 0.0012)
      discountPercent     # Discount percentage (e.g., 3)
      tierAtPurchase      # User's tier when order was created
      currency            # Original currency (e.g., "MYR")
      cryptoAmount        # Amount in crypto (e.g., 0.008511)
      cryptoCurrency      # Token used (e.g., "USDT")
    }
    errors
  }
}
```

**Example Response (3% Legend Discount):**
```json
{
  "data": {
    "createOrder": {
      "order": {
        "id": "789",
        "orderNumber": "ORD-1702123456-ABC123",
        "amount": 0.0388,
        "originalAmount": 0.04,
        "discountAmount": 0.0012,
        "discountPercent": 3,
        "tierAtPurchase": "Legend",
        "currency": "MYR",
        "cryptoAmount": 0.008511,
        "cryptoCurrency": "USDT"
      },
      "errors": null
    }
  }
}
```

---

## Frontend Implementation Examples

### 1. Display User Tier Badge

**React Example:**
```jsx
import { useQuery } from '@apollo/client';

function UserTierBadge() {
  const { data } = useQuery(GET_CURRENT_USER);
  const user = data?.currentUser;

  if (!user?.tier) {
    return null; // No tier
  }

  // Style mapping
  const tierStyles = {
    silver: {
      background: 'linear-gradient(135deg, #C0C0C0 0%, #E8E8E8 100%)',
      color: '#333',
      border: '2px solid #A0A0A0'
    },
    gold: {
      background: 'linear-gradient(135deg, #FFD700 0%, #FFA500 100%)',
      color: '#333',
      border: '2px solid #DAA520'
    },
    orange: {
      background: 'linear-gradient(135deg, #FF6B35 0%, #FF8C42 100%)',
      color: '#FFF',
      border: '2px solid #FF6B35',
      boxShadow: '0 0 20px rgba(255, 107, 53, 0.6)', // Glowing effect
      animation: 'pulse 2s infinite'
    }
  };

  const style = tierStyles[user.tierStyle] || {};

  return (
    <div className="tier-badge" style={style}>
      <span className="badge-icon">👑</span>
      <span className="badge-text">{user.tierBadge}</span>
      <span className="discount-text">{user.discountPercent}% OFF</span>
    </div>
  );
}

// CSS for pulse animation
const styles = `
  @keyframes pulse {
    0%, 100% {
      box-shadow: 0 0 20px rgba(255, 107, 53, 0.6);
    }
    50% {
      box-shadow: 0 0 30px rgba(255, 107, 53, 0.9);
    }
  }
`;
```

---

### 2. Display Username with Orange Glow (Legend Tier)

**React Example:**
```jsx
function Username({ user }) {
  const getNameStyle = () => {
    switch (user.tierStyle) {
      case 'orange':
        return {
          color: '#FF6B35',
          textShadow: '0 0 10px rgba(255, 107, 53, 0.8)',
          fontWeight: 'bold'
        };
      case 'gold':
        return {
          color: '#FFD700',
          textShadow: '0 0 8px rgba(255, 215, 0, 0.6)',
          fontWeight: 'bold'
        };
      case 'silver':
        return {
          color: '#C0C0C0',
          fontWeight: '600'
        };
      default:
        return { color: '#FFFFFF' };
    }
  };

  return (
    <span className="username" style={getNameStyle()}>
      {user.walletAddress.slice(0, 4)}...{user.walletAddress.slice(-4)}
      {user.tierBadge && <span className="tier-icon"> ✨</span>}
    </span>
  );
}
```

---

### 3. Show Discount on Product Pricing

**React Example:**
```jsx
function ProductPrice({ originalPrice, user }) {
  const discountPercent = user?.discountPercent || 0;
  const discountAmount = (originalPrice * discountPercent) / 100;
  const finalPrice = originalPrice - discountAmount;

  if (discountPercent === 0) {
    return <span className="price">${originalPrice.toFixed(2)}</span>;
  }

  return (
    <div className="price-container">
      <span className="original-price" style={{ textDecoration: 'line-through', color: '#999' }}>
        ${originalPrice.toFixed(2)}
      </span>
      <span className="final-price" style={{ color: '#00C853', fontWeight: 'bold' }}>
        ${finalPrice.toFixed(2)}
      </span>
      <span className="discount-badge" style={{
        background: getTierColor(user.tierStyle),
        color: '#FFF',
        padding: '2px 8px',
        borderRadius: '4px',
        fontSize: '12px'
      }}>
        {discountPercent}% OFF
      </span>
    </div>
  );
}

function getTierColor(style) {
  switch (style) {
    case 'orange': return '#FF6B35';
    case 'gold': return '#FFD700';
    case 'silver': return '#C0C0C0';
    default: return '#999';
  }
}
```

---

### 4. Tier Requirements Display

**React Example:**
```jsx
function TierProgressBar({ currentBalance }) {
  const tiers = [
    { name: 'Elite', required: 50000, discount: 1, style: 'silver' },
    { name: 'Grandmaster', required: 500000, discount: 2, style: 'gold' },
    { name: 'Legend', required: 3000000, discount: 3, style: 'orange' }
  ];

  const currentTier = tiers.reverse().find(t => currentBalance >= t.required) || null;
  const nextTier = tiers.find(t => currentBalance < t.required);

  return (
    <div className="tier-progress">
      <h3>Your VIP Status</h3>

      {currentTier ? (
        <div className="current-tier">
          <span className={`badge ${currentTier.style}`}>
            {currentTier.name} - {currentTier.discount}% Discount
          </span>
          <p>Balance: {currentBalance.toLocaleString()} $KOHAI</p>
        </div>
      ) : (
        <p>Hold 50,000 $KOHAI to unlock Elite tier!</p>
      )}

      {nextTier && (
        <div className="next-tier">
          <p>Next tier: {nextTier.name}</p>
          <div className="progress-bar">
            <div
              className="progress"
              style={{
                width: `${(currentBalance / nextTier.required) * 100}%`,
                background: getTierColor(nextTier.style)
              }}
            />
          </div>
          <p>
            {(nextTier.required - currentBalance).toLocaleString()} $KOHAI needed
          </p>
        </div>
      )}
    </div>
  );
}
```

---

## CSS Styling Examples

### Complete Tier Styling

```css
/* Elite (Silver) */
.tier-badge.silver {
  background: linear-gradient(135deg, #C0C0C0 0%, #E8E8E8 100%);
  color: #333;
  border: 2px solid #A0A0A0;
}

/* Grandmaster (Gold) */
.tier-badge.gold {
  background: linear-gradient(135deg, #FFD700 0%, #FFA500 100%);
  color: #333;
  border: 2px solid #DAA520;
  box-shadow: 0 0 15px rgba(255, 215, 0, 0.4);
}

/* Legend (Orange with Glow) */
.tier-badge.orange {
  background: linear-gradient(135deg, #FF6B35 0%, #FF8C42 100%);
  color: #FFF;
  border: 2px solid #FF6B35;
  box-shadow: 0 0 20px rgba(255, 107, 53, 0.6);
  animation: pulse-glow 2s ease-in-out infinite;
}

@keyframes pulse-glow {
  0%, 100% {
    box-shadow: 0 0 20px rgba(255, 107, 53, 0.6);
    transform: scale(1);
  }
  50% {
    box-shadow: 0 0 30px rgba(255, 107, 53, 0.9);
    transform: scale(1.02);
  }
}

/* Username with tier color */
.username.orange {
  color: #FF6B35;
  text-shadow: 0 0 10px rgba(255, 107, 53, 0.8);
  font-weight: bold;
  animation: text-glow 2s ease-in-out infinite;
}

@keyframes text-glow {
  0%, 100% {
    text-shadow: 0 0 10px rgba(255, 107, 53, 0.8);
  }
  50% {
    text-shadow: 0 0 15px rgba(255, 107, 53, 1);
  }
}

.username.gold {
  color: #FFD700;
  text-shadow: 0 0 8px rgba(255, 215, 0, 0.6);
  font-weight: bold;
}

.username.silver {
  color: #C0C0C0;
  font-weight: 600;
}
```

---

## When to Use Each Query

| Use Case | Query | Reason |
|----------|-------|--------|
| Display user profile/header | `currentUser { tier, tierStyle, ... }` | Uses cache, fast |
| Before creating order | `tierStatus(forceRefresh: true)` | Real-time balance check |
| Tier progress page | `tierStatus { balance, ... }` | Can use cache for display |
| After user buys $KOHAI | `tierStatus(forceRefresh: true)` | Force refresh to show new tier |
| Order confirmation | Use order data | Already has `tierAtPurchase` |

---

## Testing

### Test Different Tiers

**No Tier (0 - 49,999 $KOHAI):**
- `tier`: null
- `tierStyle`: null
- `discountPercent`: 0

**Elite Tier (50,000 - 499,999):**
- `tier`: "elite"
- `tierStyle`: "silver"
- `discountPercent`: 1

**Grandmaster Tier (500,000 - 2,999,999):**
- `tier`: "grandmaster"
- `tierStyle`: "gold"
- `discountPercent`: 2

**Legend Tier (3,000,000+):**
- `tier`: "legend"
- `tierStyle`: "orange"  👈 **This is the orange styling**
- `discountPercent`: 3

---

## Important Notes

1. **Caching:** The `currentUser` query uses 5-minute cached tier data for performance
2. **Real-time Checks:** Use `tierStatus(forceRefresh: true)` when you need the absolute latest tier
3. **Order Creation:** Backend automatically does real-time check when creating orders
4. **Styling:** The backend provides `tierStyle` field ("silver", "gold", "orange") - frontend implements the visual styling
5. **Orange Glow Effect:** For Legend tier users, apply CSS animations with orange color (#FF6B35) and glowing text-shadow/box-shadow

---

## Support

If you need help integrating or have questions:
- Check the GraphQL playground at `/graphiql` (if enabled in development)
- Contact the backend team for API questions
- Test tier changes by using different wallet addresses with varying $KOHAI balances
