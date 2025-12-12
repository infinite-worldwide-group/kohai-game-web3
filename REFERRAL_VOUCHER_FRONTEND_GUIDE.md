# Referral & Voucher System - Frontend Integration Guide

## 🎯 Overview

The referral and voucher system allows users to:
1. **Share referral codes** to invite new users
2. **Get 10% discount vouchers** when using a referral code (90 days validity, one-time use)
3. **Earn commissions** based on their KOHAI tier when referred users make purchases
4. **Claim earnings** from their vault

## 📋 Table of Contents

- [User Flows](#user-flows)
- [GraphQL API Reference](#graphql-api-reference)
- [Integration Points](#integration-points)
- [UI Components Needed](#ui-components-needed)
- [Code Examples](#code-examples)
- [Business Rules](#business-rules)

---

## 🔄 User Flows

### Flow 1: New User Applies Referral Code

```
1. New user signs up
2. User enters referral code (optional)
3. Frontend calls applyReferralCode mutation
4. Backend validates code and creates 10% voucher
5. Frontend shows success message + voucher details
6. Voucher auto-applies on first purchase
```

### Flow 2: User Shares Their Referral Code

```
1. User navigates to "Referral" page
2. Frontend calls referralCode query
3. Display user's unique code with copy button
4. Show referral stats (total referrals, earnings)
5. Provide share buttons (Twitter, Telegram, etc.)
```

### Flow 3: User Makes Purchase (Voucher Applied)

```
1. User selects product
2. Frontend calls activeVouchers query
3. Display available vouchers with discount %
4. Best discount auto-applied at checkout
5. Show original price vs discounted price
6. Order created with voucher consumed
```

### Flow 4: Referrer Claims Earnings

```
1. User navigates to "Earnings" page
2. Frontend calls referralStats query
3. Display claimable earnings
4. User clicks "Claim" button
5. Frontend calls claimEarnings mutation
6. Show transaction signature + success message
```

---

## 📡 GraphQL API Reference

### Mutations

#### 1. Apply Referral Code

**Use Case:** New user applies someone's referral code to get 10% welcome voucher

```graphql
mutation ApplyReferralCode($code: String!) {
  applyReferralCode(code: $code) {
    referral {
      id
      appliedAt
    }
    voucher {
      id
      voucherType
      discountPercent
      expiresAt
      active
    }
    message
    errors
  }
}
```

**Variables:**
```json
{
  "code": "ABC12345"
}
```

**Success Response:**
```json
{
  "data": {
    "applyReferralCode": {
      "referral": {
        "id": "1",
        "appliedAt": "2025-12-12T10:00:00Z"
      },
      "voucher": {
        "id": "1",
        "voucherType": "referral_welcome",
        "discountPercent": 10.0,
        "expiresAt": "2026-03-12T10:00:00Z",
        "active": true
      },
      "message": "Referral code applied! You received a 10% discount voucher valid for 90 days.",
      "errors": []
    }
  }
}
```

**Error Response:**
```json
{
  "data": {
    "applyReferralCode": {
      "referral": null,
      "voucher": null,
      "message": null,
      "errors": ["You have already used a referral code"]
    }
  }
}
```

**Possible Errors:**
- "You have already used a referral code"
- "Invalid referral code"
- "You cannot use your own referral code"

---

#### 2. Claim Earnings

**Use Case:** User claims accumulated referrer earnings from vault

```graphql
mutation ClaimEarnings {
  claimEarnings {
    transactionSignature
    claimedAmount
    message
    errors
  }
}
```

**Success Response:**
```json
{
  "data": {
    "claimEarnings": {
      "transactionSignature": "VAULT_CLAIM_a1b2c3d4...",
      "claimedAmount": 15.75,
      "message": "Claim initiated. Funds will be transferred from vault.",
      "errors": []
    }
  }
}
```

**No Earnings Response:**
```json
{
  "data": {
    "claimEarnings": {
      "transactionSignature": null,
      "claimedAmount": 0,
      "message": "No earnings available to claim",
      "errors": []
    }
  }
}
```

---

### Queries

#### 1. Get User's Referral Code

**Use Case:** Display user's unique referral code for sharing

```graphql
query GetReferralCode {
  referralCode {
    id
    code
    totalUses
    totalEarnings
    createdAt
  }
}
```

**Response:**
```json
{
  "data": {
    "referralCode": {
      "id": "1",
      "code": "ABC12345",
      "totalUses": 5,
      "totalEarnings": 25.50,
      "createdAt": "2025-01-01T00:00:00Z"
    }
  }
}
```

---

#### 2. Get Active Vouchers

**Use Case:** Show user's available discount vouchers at checkout

```graphql
query GetActiveVouchers {
  activeVouchers {
    id
    voucherType
    discountPercent
    expiresAt
    used
    active
    createdAt
  }
}
```

**Response:**
```json
{
  "data": {
    "activeVouchers": [
      {
        "id": "1",
        "voucherType": "referral_welcome",
        "discountPercent": 10.0,
        "expiresAt": "2026-03-12T10:00:00Z",
        "used": false,
        "active": true,
        "createdAt": "2025-12-12T10:00:00Z"
      }
    ]
  }
}
```

---

#### 3. Get Referral Stats

**Use Case:** Display referral dashboard with earnings and statistics

```graphql
query GetReferralStats {
  referralStats {
    referralCode
    totalReferrals
    totalEarnings
    claimableEarnings
    claimedEarnings
    recentEarnings {
      id
      orderAmount
      commissionPercent
      commissionAmount
      currency
      status
      claimedAt
      createdAt
    }
  }
}
```

**Response:**
```json
{
  "data": {
    "referralStats": {
      "referralCode": "ABC12345",
      "totalReferrals": 5,
      "totalEarnings": 25.50,
      "claimableEarnings": 15.75,
      "claimedEarnings": 9.75,
      "recentEarnings": [
        {
          "id": "1",
          "orderAmount": 100.0,
          "commissionPercent": 3.0,
          "commissionAmount": 3.0,
          "currency": "USDT",
          "status": "claimable",
          "claimedAt": null,
          "createdAt": "2025-12-12T10:00:00Z"
        }
      ]
    }
  }
}
```

---

## 🔌 Integration Points

### 1. User Registration Flow

**Where:** Signup page or onboarding flow

**Implementation:**
```javascript
// Add referral code input field
<input
  type="text"
  placeholder="Enter referral code (optional)"
  value={referralCode}
  onChange={(e) => setReferralCode(e.target.value.toUpperCase())}
  maxLength={8}
/>

// After successful signup
if (referralCode) {
  const result = await applyReferralCode(referralCode);
  if (result.voucher) {
    showNotification('Success! You received a 10% discount voucher!');
  }
}
```

---

### 2. Checkout/Product Page

**Where:** Product listing and checkout pages

**What to Show:**
- Original price (strikethrough if discount applies)
- Discount badge (tier or voucher)
- Final price after discount
- Voucher info if applied

**Implementation:**
```javascript
// Fetch active vouchers
const { activeVouchers } = await getActiveVouchers();

// Products already include tier-based discounts in the response
// VoucherService automatically selects best discount (tier OR voucher)
// Show the discount that will be applied:

{product.discountPercent > 0 && (
  <div className="discount-info">
    <span className="original-price">${product.price}</span>
    <span className="discount-badge">-{product.discountPercent}%</span>
    <span className="final-price">${product.discountedPrice}</span>

    {/* Show discount source */}
    {product.finalDiscountSource === 'voucher' && (
      <p className="voucher-badge">Voucher Applied</p>
    )}
    {product.finalDiscountSource === 'tier' && (
      <p className="tier-badge">{product.tierInfo.tierName} Discount</p>
    )}
  </div>
)}
```

**Note:** Backend automatically applies the best discount. Frontend just displays the result.

---

### 3. Referral Dashboard Page

**Where:** New page: `/referral` or `/earn`

**Sections to Include:**

#### A. Referral Code Card
```javascript
const { referralCode } = await getReferralCode();

<div className="referral-code-card">
  <h3>Your Referral Code</h3>
  <div className="code-display">
    <span className="code">{referralCode.code}</span>
    <button onClick={() => copyToClipboard(referralCode.code)}>
      Copy
    </button>
  </div>

  <div className="share-buttons">
    <button onClick={() => shareToTwitter(referralCode.code)}>
      Share on Twitter
    </button>
    <button onClick={() => shareToTelegram(referralCode.code)}>
      Share on Telegram
    </button>
  </div>

  <p className="stats">
    Total Uses: {referralCode.totalUses}
  </p>
</div>
```

#### B. Earnings Summary Card
```javascript
const { referralStats } = await getReferralStats();

<div className="earnings-card">
  <h3>Your Earnings</h3>

  <div className="earnings-summary">
    <div className="stat">
      <label>Claimable</label>
      <span className="amount">{referralStats.claimableEarnings} USDT</span>
    </div>
    <div className="stat">
      <label>Total Earned</label>
      <span>{referralStats.totalEarnings} USDT</span>
    </div>
    <div className="stat">
      <label>Claimed</label>
      <span>{referralStats.claimedEarnings} USDT</span>
    </div>
  </div>

  <button
    onClick={handleClaimEarnings}
    disabled={referralStats.claimableEarnings === 0}
  >
    Claim Earnings
  </button>
</div>
```

#### C. Recent Earnings Table
```javascript
<table className="earnings-history">
  <thead>
    <tr>
      <th>Date</th>
      <th>Order Amount</th>
      <th>Commission</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    {referralStats.recentEarnings.map(earning => (
      <tr key={earning.id}>
        <td>{formatDate(earning.createdAt)}</td>
        <td>{earning.orderAmount} {earning.currency}</td>
        <td>
          {earning.commissionAmount} {earning.currency}
          <span className="percent">({earning.commissionPercent}%)</span>
        </td>
        <td>
          <span className={`status-${earning.status}`}>
            {earning.status}
          </span>
        </td>
      </tr>
    ))}
  </tbody>
</table>
```

---

### 4. User Profile/Settings

**Where:** User profile page

**What to Show:**
- Whether user has applied a referral code
- Current active vouchers
- Link to referral dashboard

```javascript
// Check if user was referred
const { currentUser } = await getCurrentUser();

{currentUser.referredById && (
  <div className="referral-status">
    <p>✓ You joined via referral code</p>
  </div>
)}

// Show active vouchers
const { activeVouchers } = await getActiveVouchers();

<div className="vouchers-section">
  <h3>Active Vouchers ({activeVouchers.length})</h3>
  {activeVouchers.map(voucher => (
    <div key={voucher.id} className="voucher-card">
      <span className="discount">{voucher.discountPercent}% OFF</span>
      <span className="type">{voucher.voucherType}</span>
      <span className="expires">
        Expires: {formatDate(voucher.expiresAt)}
      </span>
    </div>
  ))}
</div>
```

---

## 🎨 UI Components Needed

### 1. Referral Code Input
- Text input (8 characters max)
- Auto-uppercase transformation
- Validation feedback
- Optional field (don't make it required)

### 2. Referral Code Display
- Large, readable code display
- Copy to clipboard button
- Share buttons (Twitter, Telegram, WhatsApp)
- QR code generator (optional)

### 3. Voucher Badge
- Show discount percentage
- Expiration countdown
- "Applied" indicator
- Hover tooltip with details

### 4. Earnings Dashboard
- Summary cards (claimable, total, claimed)
- Claim button with loading state
- Transaction history table
- Empty state when no earnings

### 5. Discount Price Display
```html
<div class="price-display">
  <!-- Original price -->
  <span class="original-price">$10.00</span>

  <!-- Discount badge -->
  <span class="discount-badge">-10%</span>

  <!-- Final price -->
  <span class="final-price">$9.00</span>

  <!-- Source indicator -->
  <p class="discount-source">
    {source === 'voucher' ? 'Voucher Applied' : 'VIP Tier Discount'}
  </p>
</div>
```

---

## 💻 Code Examples

### React Example - Apply Referral Code

```jsx
import { useMutation } from '@apollo/client';
import { useState } from 'react';

const APPLY_REFERRAL_CODE = gql`
  mutation ApplyReferralCode($code: String!) {
    applyReferralCode(code: $code) {
      voucher { discountPercent expiresAt }
      message
      errors
    }
  }
`;

function ReferralCodeInput() {
  const [code, setCode] = useState('');
  const [applyCode, { loading }] = useMutation(APPLY_REFERRAL_CODE);

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      const { data } = await applyCode({
        variables: { code: code.toUpperCase() }
      });

      if (data.applyReferralCode.errors.length > 0) {
        alert(data.applyReferralCode.errors[0]);
      } else {
        alert(data.applyReferralCode.message);
        // Navigate to dashboard or show voucher
      }
    } catch (error) {
      alert('Failed to apply referral code');
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        placeholder="Enter referral code"
        value={code}
        onChange={(e) => setCode(e.target.value.toUpperCase())}
        maxLength={8}
        pattern="[A-Z0-9]{8}"
      />
      <button type="submit" disabled={loading || code.length !== 8}>
        {loading ? 'Applying...' : 'Apply Code'}
      </button>
    </form>
  );
}
```

### React Example - Referral Dashboard

```jsx
import { useQuery, useMutation } from '@apollo/client';

const GET_REFERRAL_STATS = gql`
  query GetReferralStats {
    referralStats {
      referralCode
      totalReferrals
      claimableEarnings
      totalEarnings
      recentEarnings {
        commissionAmount
        currency
        status
        createdAt
      }
    }
  }
`;

const CLAIM_EARNINGS = gql`
  mutation ClaimEarnings {
    claimEarnings {
      transactionSignature
      claimedAmount
      message
      errors
    }
  }
`;

function ReferralDashboard() {
  const { data, loading, refetch } = useQuery(GET_REFERRAL_STATS);
  const [claimEarnings, { loading: claiming }] = useMutation(CLAIM_EARNINGS);

  const handleClaim = async () => {
    try {
      const { data } = await claimEarnings();

      if (data.claimEarnings.errors.length > 0) {
        alert(data.claimEarnings.errors[0]);
      } else {
        alert(data.claimEarnings.message);
        refetch(); // Refresh stats
      }
    } catch (error) {
      alert('Failed to claim earnings');
    }
  };

  if (loading) return <div>Loading...</div>;

  const stats = data.referralStats;

  return (
    <div className="referral-dashboard">
      <div className="referral-code-section">
        <h2>Your Referral Code</h2>
        <div className="code-display">
          <span className="code">{stats.referralCode}</span>
          <button onClick={() => navigator.clipboard.writeText(stats.referralCode)}>
            Copy
          </button>
        </div>
      </div>

      <div className="earnings-section">
        <h2>Your Earnings</h2>
        <div className="stats-grid">
          <div className="stat-card">
            <label>Claimable</label>
            <span className="amount">{stats.claimableEarnings} USDT</span>
          </div>
          <div className="stat-card">
            <label>Total Earned</label>
            <span>{stats.totalEarnings} USDT</span>
          </div>
          <div className="stat-card">
            <label>Total Referrals</label>
            <span>{stats.totalReferrals}</span>
          </div>
        </div>

        <button
          onClick={handleClaim}
          disabled={claiming || stats.claimableEarnings === 0}
        >
          {claiming ? 'Claiming...' : 'Claim Earnings'}
        </button>
      </div>

      <div className="earnings-history">
        <h3>Recent Earnings</h3>
        {stats.recentEarnings.map((earning, i) => (
          <div key={i} className="earning-item">
            <span>{earning.commissionAmount} {earning.currency}</span>
            <span className={`status-${earning.status}`}>{earning.status}</span>
            <span>{new Date(earning.createdAt).toLocaleDateString()}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## 📏 Business Rules

### Referral Code Rules
- **Format:** 8 characters, alphanumeric, case-insensitive
- **Uniqueness:** Each user gets exactly one unique code
- **Auto-generated:** Created automatically on user registration
- **Cannot be changed:** Code is permanent once created

### Voucher Rules
- **10% discount** for referral welcome vouchers
- **90-day validity** from the moment code is applied
- **One-time use:** Voucher consumed on first order
- **Auto-applied:** Best discount (tier OR voucher) applies automatically
- **No stacking:** If tier discount > voucher discount, tier discount applies

### Referral Application Rules
- **Cannot refer yourself:** User cannot use their own code
- **One referral per user:** Can only apply one referral code ever
- **Must be different user:** Referrer and referred must be different accounts
- **Immediate voucher:** Voucher created instantly upon applying code

### Commission Rules
- **Tier-based percentage:**
  - Elite tier (50k-499k KOHAI) = 1% commission
  - Grandmaster tier (500k-2.9M KOHAI) = 2% commission
  - Legend tier (3M+ KOHAI) = 3% commission
- **Earned on order success:** Commission created when order status = 'succeeded'
- **Immediately claimable:** Status = 'claimable' right away
- **Based on crypto amount:** Commission calculated on actual crypto payment amount
- **Referrer's tier matters:** Commission % based on referrer's current tier at order time

### Discount Priority
- **Backend auto-selects:** System automatically picks best discount
- **max(tier_discount, voucher_discount):** Whichever is higher
- **Stored separately:** Both tier and voucher discounts tracked on order
- **Frontend displays source:** Show which discount was applied

---

## 🎯 User Experience Tips

### 1. Onboarding
- Make referral code input **optional** during signup
- Show benefits of using a code ("Get 10% off!")
- Don't block signup if code is invalid

### 2. Referral Sharing
- Provide **easy copy** button
- Add **social share** buttons (Twitter, Telegram, WhatsApp)
- Show **progress** (how many people used your code)
- Highlight **earnings potential** based on tier

### 3. Checkout
- **Auto-apply** best discount (don't make user select)
- **Clearly show** original vs discounted price
- **Indicate source** (tier badge or voucher badge)
- **Show savings** ("You saved $5.00!")

### 4. Earnings
- **Real-time updates** when new earnings appear
- **Clear CTA** for claiming
- **Show transaction history** for transparency
- **Explain tier benefits** (upgrade tier = higher %)

### 5. Notifications
- Notify when referral code is used
- Notify when earnings are credited
- Notify when voucher is about to expire
- Notify when claim is successful

---

## 🔗 Deep Links & Share URLs

### Referral Link Format
```
https://yourdomain.com/signup?ref=ABC12345
```

Frontend should:
1. Parse `ref` query parameter
2. Pre-fill referral code input
3. Auto-apply code after signup (optional)

### Share Templates

**Twitter:**
```
Join me on [YourApp] and get 10% off your first purchase!
Use my code: ABC12345
https://yourdomain.com/signup?ref=ABC12345
```

**Telegram:**
```
🎁 Get 10% discount on your first game credit purchase!
Use referral code: ABC12345
👉 https://yourdomain.com/signup?ref=ABC12345
```

---

## ❓ FAQ for Frontend Team

### Q: When is the discount applied?
**A:** Backend automatically applies the best discount (tier OR voucher) when CreateOrder mutation is called. Frontend just needs to display the final price.

### Q: Can vouchers stack with tier discounts?
**A:** No. The system automatically picks whichever discount is higher (max of the two).

### Q: How do I know which discount was applied?
**A:** Check the `finalDiscountSource` field on the order. It will be either "tier" or "voucher".

### Q: When do earnings appear?
**A:** Earnings are created automatically when a referred user's order status becomes "succeeded". They are immediately claimable.

### Q: Can users have multiple referral codes?
**A:** No. Each user gets exactly one unique referral code that's auto-generated.

### Q: Can users change their referral code?
**A:** No. The code is permanent and cannot be changed.

### Q: What happens if a voucher expires unused?
**A:** The voucher becomes inactive (active = false) and cannot be used. User would need tier discount or a new voucher.

### Q: Can admins create promotional vouchers?
**A:** Not yet in this implementation, but the system supports it (VoucherService.create_promotional_voucher). This can be added later.

---

## 🚀 Testing Checklist

Before launching to production:

- [ ] Referral code input validation works
- [ ] Invalid codes show proper error messages
- [ ] Self-referral is blocked
- [ ] Voucher displays correctly after applying code
- [ ] Best discount auto-applies at checkout
- [ ] Price calculations are correct
- [ ] Referral dashboard shows accurate stats
- [ ] Copy button works
- [ ] Share buttons generate correct URLs
- [ ] Claim button works and updates balance
- [ ] Empty states display properly
- [ ] Loading states are shown
- [ ] Mobile responsive design
- [ ] Error handling for all mutations

---

## 📞 Need Help?

If you have questions about:
- **GraphQL schema:** Check the GraphQL playground
- **Business logic:** Contact backend team
- **UI/UX decisions:** Contact product team
- **Integration issues:** Create a ticket with error details

---

**Version:** 1.0
**Last Updated:** December 12, 2025
**Status:** Ready for Frontend Integration
