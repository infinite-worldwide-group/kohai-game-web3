# Referral System - Quick Reference Card

## 🚀 Quick Start for Frontend

### Essential GraphQL Operations

#### 1️⃣ Apply Referral Code (Signup Flow)
```graphql
mutation ApplyReferralCode($code: String!) {
  applyReferralCode(code: $code) {
    voucher { discountPercent expiresAt }
    message
    errors
  }
}
```
**Variables:** `{ "code": "ABC12345" }`

---

#### 2️⃣ Get User's Referral Code (Dashboard)
```graphql
query {
  referralCode {
    code
    totalUses
    totalEarnings
  }
}
```

---

#### 3️⃣ Get Referral Stats (Dashboard)
```graphql
query {
  referralStats {
    referralCode
    totalReferrals
    claimableEarnings
    totalEarnings
    recentEarnings {
      commissionAmount
      currency
      status
    }
  }
}
```

---

#### 4️⃣ Get Active Vouchers (Checkout)
```graphql
query {
  activeVouchers {
    discountPercent
    expiresAt
    active
  }
}
```

---

#### 5️⃣ Claim Earnings
```graphql
mutation {
  claimEarnings {
    transactionSignature
    claimedAmount
    message
  }
}
```

---

## 📍 Where to Use

| Location | Query/Mutation | Purpose |
|----------|---------------|---------|
| Signup Page | `applyReferralCode` | Let user enter referral code |
| Profile/Dashboard | `referralCode` | Show user's code to share |
| Referral Page | `referralStats` | Full earnings dashboard |
| Checkout | `activeVouchers` | Show available discounts |
| Earnings Page | `claimEarnings` | Let user withdraw earnings |

---

## 🎯 Key Business Rules

| Rule | Value |
|------|-------|
| Voucher Discount | **10%** |
| Voucher Validity | **90 days** |
| Voucher Usage | **One-time only** |
| Elite Commission | **1%** |
| Grandmaster Commission | **2%** |
| Legend Commission | **3%** |
| Code Format | **8 alphanumeric chars** |
| Self-Referral | **❌ Blocked** |
| Discount Stacking | **❌ No (takes max)** |

---

## 💡 Common Patterns

### Pattern 1: Signup with Referral
```javascript
// 1. Get code from URL: ?ref=ABC12345
const urlParams = new URLSearchParams(window.location.search);
const refCode = urlParams.get('ref');

// 2. After signup, apply code
if (refCode) {
  await applyReferralCode({ variables: { code: refCode } });
}
```

### Pattern 2: Copy Referral Code
```javascript
const { data } = await getReferralCode();
navigator.clipboard.writeText(data.referralCode.code);
```

### Pattern 3: Share Referral Link
```javascript
const { data } = await getReferralCode();
const shareUrl = `https://yourapp.com/signup?ref=${data.referralCode.code}`;
```

### Pattern 4: Display Discount at Checkout
```javascript
// Backend auto-applies best discount
// Just show the result:
<div>
  <s>${product.price}</s> {/* Original */}
  <strong>${product.discountedPrice}</strong> {/* After discount */}
  <span>-{product.discountPercent}%</span>
</div>
```

---

## ⚠️ Important Notes

1. **Auto-Apply Discount:** Backend automatically picks tier OR voucher (whichever is higher). Don't let user choose.

2. **No Stacking:** Tier discount and voucher discount don't stack. System uses the better one.

3. **One Referral Only:** Users can only apply ONE referral code ever. Show warning before applying.

4. **Instant Earnings:** When referred user's order succeeds, earnings appear immediately (status: 'claimable').

5. **Commission Based on Referrer's Tier:** The person who shared the code earns based on THEIR tier level, not the buyer's tier.

---

## 🎨 UI Components Checklist

- [ ] Referral code input (8 chars, uppercase)
- [ ] Copy to clipboard button
- [ ] Share buttons (Twitter, Telegram)
- [ ] Earnings summary cards
- [ ] Claim button with loading state
- [ ] Voucher badge on products
- [ ] Price comparison (original vs discounted)
- [ ] Transaction history table

---

## 📱 Mobile Considerations

- Make referral code **large and tappable**
- Use **native share API** on mobile
- Show **copy success** feedback
- Keep earnings dashboard **simple** (cards instead of tables)

---

## 🐛 Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Invalid referral code" | Code doesn't exist | Ask user to check code |
| "You have already used a referral code" | User already referred | Show info message |
| "You cannot use your own referral code" | Self-referral attempt | Block with UI validation |
| "No earnings available to claim" | No claimable earnings | Disable claim button |

---

## 🔗 Quick Links

- Full Documentation: `REFERRAL_VOUCHER_FRONTEND_GUIDE.md`
- GraphQL Playground: `http://localhost:3000/graphiql`
- Backend Team: Contact for support

---

**Last Updated:** December 12, 2025
