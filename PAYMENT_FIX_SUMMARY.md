# Payment Error Fix Summary

## Problem
Backend error: "Amount must be greater than 0" when trying to purchase Product ID 56 (16 Tokens for $0.01 MYR)

## Root Causes

### 1. Missing TopupProductService
The checkout mutation was calling `TopupProductService.checkout` which didn't exist.

### 2. Database Precision Issue
The `orders.amount` column only supported 2 decimal places (`precision: 15, scale: 2`).
When converting 0.01 MYR to USDT (0.00242131 USDT), it was rounded to 0.00, failing validation.

### 3. Currency Conversion Not Applied
The vendor API was receiving the price in MYR instead of USDT, causing the "Amount must be greater than 0" error.

### 4. Missing Platform Wallet Address
The checkout response didn't include the platform wallet address, causing incorrect payment destinations.

## Solutions Implemented

### 1. Created TopupProductService (`app/services/topup_product_service.rb`)
- Handles complete checkout flow
- Converts prices: MYR → USDT → SOL
- Creates orders with proper currency fields
- Returns checkout data with payment details

### 2. Database Migration
Created migration `20251205072500_increase_order_amount_precision.rb`:
```ruby
# Changed from precision: 15, scale: 2
# To:          precision: 18, scale: 8
change_column :orders, :amount, :decimal, precision: 18, scale: 8
```

### 3. Updated VendorService
Modified `create_order` method to:
- Accept `price_usdt` parameter
- Convert MYR prices to USDT before sending to vendor
- Ensure vendor receives amounts in USDT (not MYR)

### 4. Updated OrderService
Modified `post_purchase` to pass USDT price to vendor.

### 5. Added Platform Wallet to Response
- Checkout now returns `wallet_to` field with platform wallet address
- Created GraphQL type `TopupProductCheckoutType` with all payment fields

### 6. Added Missing Scopes to Order Model
```ruby
scope :topup_product, -> { where(order_type: 'topup_product') }
scope :pending, -> { where(status: 'pending') }
scope :succeeded, -> { where(status: 'succeeded') }
```

## Test Results

### Before Fix
- Product price: 0.01 MYR
- Converted to USDT: 0.00242131
- Database stored: 0.00 (rounded due to 2 decimal places)
- Validation: **FAILED** - "Amount must be greater than 0"

### After Fix
- Product price: 0.01 MYR
- Converted to USDT: 0.00242131 ✓
- Database stored: 0.00242131 ✓
- Validation: **PASSED** ✓
- Order created successfully ✓
- Payment flow completed ✓

## Payment Flow

### 1. Checkout
```ruby
TopupProductService.checkout(
  user: current_user,
  checkout_input: input,
  validation_data: {}
)
```

Returns:
```ruby
{
  order_number: "3FZFMHOK07025A12A0C2",
  order_id: 24,
  payment_amount: 0.000017541,  # SOL amount
  payment_currency: "SOL",
  wallet_to: "zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE",  # Platform wallet
  price_usdt: 0.00242131,
  price_myr: 0.01,
  status: "pending",
  expires_at: "2025-12-05 08:36:42 UTC"
}
```

### 2. Payment
User sends `payment_amount` SOL to `wallet_to` address.

### 3. Verification
Create `CryptoTransaction` record:
```ruby
CryptoTransaction.create!(
  order: order,
  transaction_signature: "...",
  wallet_from: user.wallet_address,
  wallet_to: platform_wallet,  # Correct platform wallet
  amount: payment_amount,
  token: "SOL",
  state: "confirmed"
)
```

### 4. Mark as Paid
```ruby
order.pay!  # Changes status from 'pending' to 'paid'
```

## Files Modified

1. **NEW** `app/services/topup_product_service.rb` - Checkout service
2. **NEW** `app/graphql/types/topup_product_checkout_type.rb` - GraphQL type
3. **NEW** `db/migrate/20251205072500_increase_order_amount_precision.rb` - Migration
4. `app/services/vendor_service.rb` - Added USDT conversion
5. `app/services/order_service.rb` - Pass USDT price to vendor
6. `app/models/order.rb` - Added missing scopes

## Currency Conversion Flow

```
MYR (Product Price)
  ↓ CurrencyConversionService.convert()
USDT (Stored in order.amount, sent to vendor)
  ↓ CurrencyConversionService.usd_to_sol()
SOL (Stored in order.crypto_amount, paid by user)
```

## Example for Product ID 56

- **Product**: Honor of Kings - 16 Tokens
- **Price**: 0.01 MYR
- **Converted**: 0.00242131 USDT
- **Payment**: 0.000017541 SOL
- **Status**: ✓ Working correctly

## Migration Instructions

Run this migration in production:
```bash
rails db:migrate
```

This will update the `orders` table to support more decimal precision for small crypto amounts.
