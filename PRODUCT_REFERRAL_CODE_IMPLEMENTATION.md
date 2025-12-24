# Product Page Referral Code Input - Implementation Guide

## Overview
Add a referral/promo code input field to the product/checkout page so users can apply referral codes when making purchases.

---

## Backend Status ✅
The backend is fully implemented with these endpoints:

### NEW: User Referral Status Fields

The User type now includes these fields to check if a user has already applied a referral code:

```graphql
type User {
  # ... other fields

  # Referral status fields
  hasAppliedReferralCode: Boolean!    # true if user already used a code
  appliedReferralCode: String         # The actual code they applied (e.g., "ABC12345")
  referredById: ID                    # ID of the user who referred them
  referralAppliedAt: DateTime         # When they applied the code
}
```

**Usage in Frontend:**
```graphql
query GetCurrentUser {
  currentUser {
    id
    walletAddress
    hasAppliedReferralCode
    appliedReferralCode
    referredById
  }
}
```

---

### GraphQL Mutation: `applyReferralCode`
**Location:** `/app/graphql/mutations/referrals/apply_referral_code.rb`

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

**What it does:**
- Validates the referral code
- Creates a 10% discount voucher (valid for 90 days)
- Links the referrer and referred user
- Returns success message or errors

**Business Rules:**
- Code must be exactly 8 characters
- User cannot use their own code
- User can only apply one referral code ever
- Voucher is auto-applied on checkout (best discount wins)

---

## Frontend Implementation

### 1. Create GraphQL Mutation Hook

**File:** `src/graphql/mutations/applyReferralCode.ts`

```typescript
import { gql } from '@apollo/client';

export const APPLY_REFERRAL_CODE = gql`
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
`;
```

---

### 2. Create Referral Code Input Component

**File:** `src/components/ReferralCodeInput/index.tsx`

```tsx
import React, { useState } from 'react';
import { useMutation } from '@apollo/client';
import { APPLY_REFERRAL_CODE } from '@/graphql/mutations/applyReferralCode';

interface ReferralCodeInputProps {
  onSuccess?: (voucher: any) => void;
  onError?: (error: string) => void;
}

export const ReferralCodeInput: React.FC<ReferralCodeInputProps> = ({
  onSuccess,
  onError
}) => {
  const [code, setCode] = useState('');
  const [isExpanded, setIsExpanded] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');

  const [applyCode, { loading }] = useMutation(APPLY_REFERRAL_CODE, {
    onCompleted: (data) => {
      if (data.applyReferralCode.errors.length > 0) {
        const errorMsg = data.applyReferralCode.errors[0];
        setSuccessMessage('');
        onError?.(errorMsg);
      } else {
        setSuccessMessage(data.applyReferralCode.message);
        onSuccess?.(data.applyReferralCode.voucher);
        setCode('');

        // Auto-collapse after success
        setTimeout(() => {
          setIsExpanded(false);
        }, 3000);
      }
    },
    onError: (error) => {
      onError?.('Failed to apply referral code. Please try again.');
    }
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (code.length !== 8) {
      onError?.('Referral code must be 8 characters');
      return;
    }

    await applyCode({
      variables: { code: code.toUpperCase() }
    });
  };

  const handleCodeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value.toUpperCase();
    if (value.length <= 8) {
      setCode(value);
    }
  };

  return (
    <div className="referral-code-section">
      {!isExpanded ? (
        <button
          type="button"
          onClick={() => setIsExpanded(true)}
          className="promo-code-toggle"
        >
          Have a promo code?
        </button>
      ) : (
        <form onSubmit={handleSubmit} className="promo-code-form">
          <div className="input-group">
            <input
              type="text"
              value={code}
              onChange={handleCodeChange}
              placeholder="Enter 8-character code"
              className="promo-code-input"
              maxLength={8}
              pattern="[A-Z0-9]{8}"
              disabled={loading}
            />
            <button
              type="submit"
              disabled={loading || code.length !== 8}
              className="apply-button"
            >
              {loading ? 'Applying...' : 'Apply'}
            </button>
          </div>

          {successMessage && (
            <p className="success-message">
              ✓ {successMessage}
            </p>
          )}

          <button
            type="button"
            onClick={() => setIsExpanded(false)}
            className="cancel-button"
          >
            Cancel
          </button>
        </form>
      )}
    </div>
  );
};
```

---

### 3. Integrate into Product/Checkout Page

**Option A: Add to Product Selection Page**

```tsx
import { ReferralCodeInput } from '@/components/ReferralCodeInput';

function ProductPage() {
  const [showVoucherApplied, setShowVoucherApplied] = useState(false);

  const handleReferralSuccess = (voucher: any) => {
    setShowVoucherApplied(true);
    toast.success(`You got a ${voucher.discountPercent}% discount voucher!`);

    // Refetch active vouchers to show the new one
    refetchActiveVouchers();
  };

  const handleReferralError = (error: string) => {
    toast.error(error);
  };

  return (
    <div className="product-page">
      {/* Product details */}
      <ProductDetails product={product} />

      {/* Referral code input */}
      <ReferralCodeInput
        onSuccess={handleReferralSuccess}
        onError={handleReferralError}
      />

      {showVoucherApplied && (
        <div className="voucher-applied-notice">
          🎉 Your 10% discount will be applied at checkout!
        </div>
      )}

      {/* Continue to checkout */}
      <CheckoutButton />
    </div>
  );
}
```

**Option B: Add to Checkout Page (with User Status Check)**

```tsx
import { ReferralCodeInput } from '@/components/ReferralCodeInput';
import { useQuery } from '@apollo/client';

const GET_CURRENT_USER = gql`
  query GetCurrentUser {
    currentUser {
      id
      hasAppliedReferralCode
      appliedReferralCode
      referredById
    }
  }
`;

function CheckoutPage() {
  const { data: vouchersData } = useQuery(GET_ACTIVE_VOUCHERS);
  const { data: userData } = useQuery(GET_CURRENT_USER);

  const handleReferralSuccess = (voucher: any) => {
    // Voucher will auto-apply to order
    toast.success('Discount voucher added! It will be applied to your order.');
  };

  const currentUser = userData?.currentUser;
  const hasAppliedCode = currentUser?.hasAppliedReferralCode;

  return (
    <div className="checkout-page">
      <h2>Checkout</h2>

      {/* Order summary */}
      <OrderSummary
        originalPrice={product.price}
        discountedPrice={product.discountedPrice}
        activeVouchers={vouchersData?.activeVouchers}
      />

      {/* Show referral code input only if user hasn't applied a code yet */}
      {!hasAppliedCode && (
        <ReferralCodeInput
          onSuccess={handleReferralSuccess}
          onError={(error) => toast.error(error)}
        />
      )}

      {/* Show message if user already applied a code */}
      {hasAppliedCode && (
        <div className="referral-applied-message">
          ✓ You joined with referral code: {currentUser.appliedReferralCode}
        </div>
      )}

      {/* Payment section */}
      <PaymentSection />
    </div>
  );
}
```

---

### 4. Smart Conditional Display Logic

**Best Practice:** Only show the referral code input if the user hasn't already applied a code.

```tsx
import { useQuery } from '@apollo/client';

const GET_USER_REFERRAL_STATUS = gql`
  query GetUserReferralStatus {
    currentUser {
      id
      hasAppliedReferralCode
      appliedReferralCode
    }
  }
`;

function SmartReferralInput() {
  const { data, loading } = useQuery(GET_USER_REFERRAL_STATUS);

  if (loading) return null;

  const hasApplied = data?.currentUser?.hasAppliedReferralCode;
  const appliedCode = data?.currentUser?.appliedReferralCode;

  // Don't show input if user already applied a code
  if (hasApplied) {
    return (
      <div className="referral-status-badge">
        <span className="icon">✓</span>
        <span>Referred with code: <strong>{appliedCode}</strong></span>
      </div>
    );
  }

  // Show input for users who haven't applied a code yet
  return (
    <ReferralCodeInput
      onSuccess={(voucher) => {
        toast.success(`You got ${voucher.discountPercent}% off!`);
      }}
      onError={(error) => {
        toast.error(error);
      }}
    />
  );
}
```

**Business Logic:**
- User can only apply **ONE** referral code **EVER**
- Once applied, the input should be hidden
- Show a badge/message indicating they were referred
- This prevents confusion and repeat attempts

---

### 5. CSS Styling Example

**File:** `src/components/ReferralCodeInput/styles.css`

```css
.referral-code-section {
  margin: 1rem 0;
  padding: 1rem;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  background: #f9f9f9;
}

.promo-code-toggle {
  background: none;
  border: none;
  color: #007bff;
  cursor: pointer;
  text-decoration: underline;
  font-size: 0.95rem;
  padding: 0;
}

.promo-code-toggle:hover {
  color: #0056b3;
}

.promo-code-form {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.input-group {
  display: flex;
  gap: 0.5rem;
}

.promo-code-input {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 1rem;
  text-transform: uppercase;
  font-family: monospace;
  letter-spacing: 0.1em;
}

.promo-code-input:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.1);
}

.promo-code-input:disabled {
  background: #f5f5f5;
  cursor: not-allowed;
}

.apply-button {
  padding: 0.75rem 1.5rem;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 600;
  transition: background 0.2s;
}

.apply-button:hover:not(:disabled) {
  background: #0056b3;
}

.apply-button:disabled {
  background: #cccccc;
  cursor: not-allowed;
}

.success-message {
  color: #28a745;
  margin: 0;
  font-size: 0.9rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.cancel-button {
  background: none;
  border: none;
  color: #666;
  cursor: pointer;
  font-size: 0.85rem;
  padding: 0.25rem;
}

.cancel-button:hover {
  color: #333;
  text-decoration: underline;
}

.voucher-applied-notice {
  padding: 1rem;
  background: #d4edda;
  border: 1px solid #c3e6cb;
  border-radius: 4px;
  color: #155724;
  margin: 1rem 0;
}

.referral-status-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  background: #e7f3ff;
  border: 1px solid #b3d9ff;
  border-radius: 4px;
  color: #004085;
  font-size: 0.9rem;
}

.referral-status-badge .icon {
  color: #28a745;
  font-size: 1.1rem;
}

.referral-applied-message {
  padding: 0.75rem 1rem;
  background: #d1ecf1;
  border: 1px solid #bee5eb;
  border-radius: 4px;
  color: #0c5460;
  font-size: 0.9rem;
}
```

---

### 5. Enhanced Version with Toast Notifications

If you're using a toast library (like react-hot-toast):

```tsx
import toast from 'react-hot-toast';

const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault();

  if (code.length !== 8) {
    toast.error('Referral code must be 8 characters');
    return;
  }

  const toastId = toast.loading('Applying referral code...');

  try {
    const { data } = await applyCode({
      variables: { code: code.toUpperCase() }
    });

    if (data.applyReferralCode.errors.length > 0) {
      toast.error(data.applyReferralCode.errors[0], { id: toastId });
    } else {
      toast.success(
        `Success! You received a ${data.applyReferralCode.voucher.discountPercent}% discount voucher!`,
        { id: toastId, duration: 5000 }
      );
      onSuccess?.(data.applyReferralCode.voucher);
      setCode('');
      setTimeout(() => setIsExpanded(false), 3000);
    }
  } catch (error) {
    toast.error('Failed to apply code. Please try again.', { id: toastId });
  }
};
```

---

## Integration Points

### Where to Add the Component:

1. **Product Selection Page** (Before checkout button)
   - User selects product → sees "Have a promo code?" → applies code → sees success → proceeds to checkout

2. **Checkout Page** (In order summary section)
   - User at checkout → can still apply promo code → voucher auto-applies to order

3. **User Dashboard/Profile** (Standalone section)
   - User can apply codes anytime from their profile

---

## User Flow

```
1. User browses products
   ↓
2. User sees "Have a promo code?" link
   ↓
3. User clicks → input field expands
   ↓
4. User enters 8-character code (e.g., "ABC12345")
   ↓
5. User clicks "Apply"
   ↓
6. Backend validates code
   ↓
7a. SUCCESS:
    - Creates 10% voucher (90-day validity)
    - Shows success message
    - Voucher auto-applies at checkout
    ↓
7b. ERROR:
    - Shows error message
    - "Invalid code"
    - "You already used a referral code"
    - "Cannot use your own code"
    ↓
8. User proceeds to checkout
   ↓
9. Best discount (tier OR voucher) auto-applies
```

---

## Error Handling

Handle these common errors:

```tsx
const ERROR_MESSAGES = {
  'You have already used a referral code':
    'You have already applied a referral code to your account.',
  'Invalid referral code':
    'This code is not valid. Please check and try again.',
  'You cannot use your own referral code':
    'You cannot use your own referral code.',
};

const displayError = (error: string) => {
  const friendlyMessage = ERROR_MESSAGES[error] || error;
  toast.error(friendlyMessage);
};
```

---

## Testing Checklist

- [ ] Input accepts only alphanumeric characters
- [ ] Input auto-converts to uppercase
- [ ] Input limits to 8 characters
- [ ] Submit button disabled when code length < 8
- [ ] Success message shows voucher details
- [ ] Error messages display correctly
- [ ] Form resets after successful submission
- [ ] Loading state shows during API call
- [ ] Component collapses after success
- [ ] Voucher appears in active vouchers list
- [ ] Discount applies correctly at checkout

---

## Next Steps

1. Add the `ReferralCodeInput` component to your frontend codebase
2. Import it into your Product or Checkout page
3. Style it to match your design system
4. Test with valid/invalid codes
5. Verify the voucher applies correctly at checkout

---

## Additional Features (Optional)

### Auto-apply from URL parameter
```tsx
// In your Product/Checkout page
const searchParams = useSearchParams();
const refCode = searchParams.get('ref');

useEffect(() => {
  if (refCode) {
    // Auto-expand input and pre-fill code
    setCode(refCode);
    setIsExpanded(true);
  }
}, [refCode]);
```

### QR Code Support
```tsx
import QRCode from 'qrcode.react';

<QRCode
  value={`https://yoursite.com/signup?ref=${referralCode}`}
  size={200}
/>
```

---

**Questions?** Refer to:
- `REFERRAL_VOUCHER_FRONTEND_GUIDE.md` - Complete integration guide
- GraphQL playground at `/graphiql` - Test mutations directly
