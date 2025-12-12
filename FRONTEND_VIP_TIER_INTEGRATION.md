# Frontend VIP Tier Integration Guide

## Overview
The backend now supports a VIP tier system based on $KOHAI token holdings. Users receive permanent discounts on all game topup purchases based on their token balance.

## Tier Levels

| Tier | Token Holdings | Discount | Badge Name | Badge Color |
|------|----------------|----------|------------|-------------|
| **Elite VIP** | 50,000 - 499,999 $KOHAI | 1% | ELITE VIP | silver |
| **Master VVIP** | 500,000 - 2,999,999 $KOHAI | 2% | MASTER VVIP | gold |
| **Champion VVIP+** | 3,000,000+ $KOHAI | 3% | CHAMPION VVIP+ | orange |

## GraphQL Queries

### 1. Get Current User's Tier Status

```graphql
query GetTierStatus($forceRefresh: Boolean) {
  tierStatus(forceRefresh: $forceRefresh) {
    tier              # "elite", "master", "champion", or null
    tierName          # "Elite VIP", "Master VVIP", "Champion VVIP+"
    discountPercent   # 1, 2, 3, or 0
    referralPercent   # Same as discount (for future referral system)
    badge             # "ELITE VIP", "MASTER VVIP", "CHAMPION VVIP+"
    style             # "silver", "gold", "orange" (for UI styling)
    balance           # Current $KOHAI token balance
    cached            # true if from cache, false if fresh from blockchain
    lastCheckedAt     # When tier was last checked
  }
}
```

**Parameters:**
- `forceRefresh`: Set to `true` to fetch fresh data from blockchain (default: `false`, uses 5-minute cache)

**Example Response:**
```json
{
  "data": {
    "tierStatus": {
      "tier": "master",
      "tierName": "Master VVIP",
      "discountPercent": 2,
      "referralPercent": 2,
      "badge": "MASTER VVIP",
      "style": "gold",
      "balance": 750000.0,
      "cached": true,
      "lastCheckedAt": "2025-12-11T10:30:00Z"
    }
  }
}
```

### 2. Get User Info with Tier (Alternative)

```graphql
query GetCurrentUser {
  currentUser {
    id
    walletAddress
    tier              # "elite", "master", "champion"
    tierName          # Display name
    discountPercent   # Current discount %
    kohaiBalance      # Token balance
    tierBadge         # Badge text
    tierStyle         # UI style color
  }
}
```

### 3. Get Topup Products with Discounted Prices

```graphql
query GetTopupProducts {
  topupProducts {
    id
    title
    slug
    logoUrl
    topupProductItems {
      id
      name
      price                    # Original price in MYR
      currency                 # "MYR"
      priceInUsdt             # Original price in USDT

      # Discount fields (calculated based on logged-in user's tier)
      discountPercent         # User's discount % (0, 1, 2, or 3)
      discountAmount          # Discount amount in MYR
      discountedPrice         # Final price in MYR after discount
      discountedPriceUsdt     # Final price in USDT after discount

      # Tier information
      tierInfo {
        tier              # User's tier key
        tierName          # Display name
        discountPercent   # Discount percentage
        badge             # Badge text
        style             # Badge color
        balance           # Token balance
      }
    }
  }
}
```

**Example Response:**
```json
{
  "data": {
    "topupProducts": [
      {
        "id": "1",
        "title": "Mobile Legends",
        "topupProductItems": [
          {
            "id": "101",
            "name": "100 Diamonds",
            "price": 10.0,
            "currency": "MYR",
            "priceInUsdt": 2.2,
            "discountPercent": 2,
            "discountAmount": 0.2,
            "discountedPrice": 9.8,
            "discountedPriceUsdt": 2.156,
            "tierInfo": {
              "tier": "master",
              "tierName": "Master VVIP",
              "discountPercent": 2,
              "badge": "MASTER VVIP",
              "style": "gold",
              "balance": 750000.0
            }
          }
        ]
      }
    ]
  }
}
```

### 4. Get All Available Tiers (for displaying tier information page)

```graphql
query GetAllTiers {
  tiers {
    id
    name              # "Elite VIP", "Master VVIP", "Champion VVIP+"
    tierKey           # "elite", "master", "champion"
    minimumBalance    # 50000, 500000, 3000000
    discountPercent   # 1, 2, 3
    badgeName         # "ELITE VIP", "MASTER VVIP", "CHAMPION VVIP+"
    badgeColor        # "silver", "gold", "orange"
    description       # Full description
    displayOrder      # 1, 2, 3
    isActive          # true
  }
}
```

## Frontend Implementation Guide

### 1. Display User's Tier Badge

```javascript
// Fetch user tier on login/wallet connection
const { data } = await apolloClient.query({
  query: GET_TIER_STATUS,
  variables: { forceRefresh: false } // Use cache for better performance
});

const tierInfo = data.tierStatus;

// Display badge
if (tierInfo.badge) {
  return (
    <Badge className={`tier-badge tier-${tierInfo.style}`}>
      {tierInfo.badge}
    </Badge>
  );
}
```

**CSS Styling:**
```css
.tier-badge {
  padding: 4px 12px;
  border-radius: 16px;
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
}

.tier-badge.tier-silver {
  background: linear-gradient(135deg, #C0C0C0, #E8E8E8);
  color: #333;
  box-shadow: 0 2px 4px rgba(192, 192, 192, 0.5);
}

.tier-badge.tier-gold {
  background: linear-gradient(135deg, #FFD700, #FFA500);
  color: #333;
  box-shadow: 0 2px 4px rgba(255, 215, 0, 0.5);
}

.tier-badge.tier-orange {
  background: linear-gradient(135deg, #FF6B35, #FF8C42);
  color: white;
  box-shadow: 0 2px 4px rgba(255, 107, 53, 0.5);
  animation: glow 2s ease-in-out infinite;
}

@keyframes glow {
  0%, 100% { box-shadow: 0 2px 8px rgba(255, 107, 53, 0.5); }
  50% { box-shadow: 0 2px 16px rgba(255, 107, 53, 0.8); }
}
```

### 2. Display Discounted Prices on Product Cards

```javascript
// In your product item component
function ProductItemCard({ item }) {
  const hasDiscount = item.discountPercent > 0;

  return (
    <div className="product-card">
      <h3>{item.name}</h3>

      <div className="price-section">
        {hasDiscount ? (
          <>
            {/* Show original price with strikethrough */}
            <span className="original-price">
              {item.currency} {item.price.toFixed(2)}
            </span>

            {/* Show discounted price prominently */}
            <span className="discounted-price">
              {item.currency} {item.discountedPrice.toFixed(2)}
            </span>

            {/* Show discount badge */}
            <span className="discount-badge">
              -{item.discountPercent}% OFF
            </span>
          </>
        ) : (
          <span className="price">
            {item.currency} {item.price.toFixed(2)}
          </span>
        )}
      </div>

      {/* Show USDT equivalent */}
      <div className="usdt-price">
        ≈ {hasDiscount ? item.discountedPriceUsdt.toFixed(4) : item.priceInUsdt.toFixed(4)} USDT
      </div>
    </div>
  );
}
```

### 3. Display Tier Benefits Page

```javascript
function TierBenefitsPage() {
  const { data } = useQuery(GET_ALL_TIERS);
  const { data: userTier } = useQuery(GET_TIER_STATUS);

  return (
    <div className="tier-benefits">
      <h1>VIP Tier Benefits</h1>
      <p>Hold $KOHAI tokens to unlock permanent discounts!</p>

      {/* Show current tier */}
      {userTier?.tierStatus?.badge && (
        <div className="current-tier">
          <h2>Your Current Tier</h2>
          <Badge className={`tier-${userTier.tierStatus.style}`}>
            {userTier.tierStatus.badge}
          </Badge>
          <p>Balance: {userTier.tierStatus.balance.toLocaleString()} $KOHAI</p>
          <p>Discount: {userTier.tierStatus.discountPercent}% on all purchases</p>
        </div>
      )}

      {/* Show all available tiers */}
      <div className="tiers-grid">
        {data?.tiers?.map(tier => (
          <div key={tier.id} className={`tier-card tier-${tier.badgeColor}`}>
            <h3>{tier.name}</h3>
            <div className="badge">{tier.badgeName}</div>
            <div className="requirement">
              Hold {tier.minimumBalance.toLocaleString()}+ $KOHAI
            </div>
            <div className="benefit">
              {tier.discountPercent}% Discount Forever
            </div>
            <p className="description">{tier.description}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
```

### 4. Refresh Tier Status (After User Buys Tokens)

```javascript
// After user purchases $KOHAI tokens, refresh their tier
async function handleTokenPurchase() {
  // ... token purchase logic ...

  // Force refresh tier from blockchain
  await apolloClient.query({
    query: GET_TIER_STATUS,
    variables: { forceRefresh: true },
    fetchPolicy: 'network-only' // Bypass cache
  });

  // Show notification if tier upgraded
  showNotification("Congratulations! Your tier has been updated!");
}
```

## Important Notes

1. **Caching**: The backend caches tier status for 5 minutes to reduce blockchain RPC calls. Set `forceRefresh: true` only when necessary (e.g., after token purchase).

2. **Discount Calculation**: Discounts are automatically calculated on the backend based on the authenticated user. No need to calculate discounts on the frontend.

3. **Authentication Required**: All discount fields return 0 for unauthenticated users. Make sure users are logged in with their wallet to see their discounts.

4. **Real-time Updates**: The tier is checked against the Solana blockchain. If a user's token balance changes, their tier will update within 5 minutes (or immediately with `forceRefresh: true`).

5. **Badge Display**: Always use the `badge`, `style`, and `tierName` fields from the API for consistency. Don't hardcode tier names on the frontend.

## Example User Flows

### Flow 1: New User Checking Benefits
1. User visits the site without tokens
2. Show "VIP Tier Benefits" page with all tiers
3. User sees they can get discounts by holding $KOHAI
4. Show "Get $KOHAI" CTA button

### Flow 2: Existing User Making Purchase
1. User logs in with wallet
2. Fetch `tierStatus` query (cached, fast)
3. Display user's badge in header/profile
4. When viewing products, show discounted prices automatically
5. At checkout, confirm the discounted price

### Flow 3: User Just Bought Tokens
1. User purchases $KOHAI tokens
2. Frontend calls `tierStatus(forceRefresh: true)`
3. Backend checks blockchain
4. If tier changed, show congratulations modal
5. Update all prices across the app

## Testing

You can test with these example wallets (if you have test data):

```javascript
// Example queries for testing
const TEST_CASES = [
  {
    description: "No tokens - No tier",
    expectedDiscount: 0,
    expectedBadge: null
  },
  {
    description: "75,000 tokens - Elite VIP",
    expectedDiscount: 1,
    expectedBadge: "ELITE VIP",
    expectedStyle: "silver"
  },
  {
    description: "750,000 tokens - Master VVIP",
    expectedDiscount: 2,
    expectedBadge: "MASTER VVIP",
    expectedStyle: "gold"
  },
  {
    description: "5,000,000 tokens - Champion VVIP+",
    expectedDiscount: 3,
    expectedBadge: "CHAMPION VVIP+",
    expectedStyle: "orange"
  }
];
```

## Support

If you encounter any issues:
1. Check that the user is authenticated (wallet connected)
2. Verify the GraphQL query includes the discount fields
3. Check browser console for GraphQL errors
4. Try `forceRefresh: true` to bypass cache

For backend issues, contact the backend team with:
- User's wallet address
- Expected vs actual tier
- Error messages from GraphQL response
