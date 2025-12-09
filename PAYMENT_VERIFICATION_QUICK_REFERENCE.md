# Payment Verification - Quick Reference

## ✅ What Gets Verified Before Confirming Order

Before marking an order as "paid", the system automatically verifies:

| Check | Description | Action |
|-------|-------------|--------|
| 🔍 **Transaction Exists** | Transaction found on Solana blockchain | Queries Solana RPC API |
| ✅ **Confirmed Status** | Transaction is confirmed/finalized | Checks confirmation status |
| 💰 **Amount Match** | Payment amount ≥ order amount (1% tolerance) | Compares amounts |
| 📍 **Correct Receiver** | Payment sent to platform wallet | Verifies `wallet_to` |
| 👤 **Correct Sender** | Payment from user's wallet | Verifies `wallet_from` |
| 🚫 **No Duplicates** | Transaction not already used | Checks database |

## 🔄 Complete Flow

```
1. Checkout
   └─> Creates order with status: "pending"
   └─> Returns: payment_amount, wallet_to, order_id

2. User Pays
   └─> Sends SOL from wallet to platform_wallet
   └─> Gets: transaction_signature

3. Confirm Payment (NEW!)
   └─> Calls: confirmPayment(orderId, transactionSignature)
   └─> Verifies transaction on Solana blockchain
   └─> Creates CryptoTransaction record
   └─> Updates order status: "pending" → "paid"
```

## 📋 GraphQL Mutation

```graphql
mutation ConfirmPayment($orderId: ID!, $transactionSignature: String!) {
  confirmPayment(
    orderId: $orderId
    transactionSignature: $transactionSignature
  ) {
    verified
    order {
      id
      status
      cryptoAmount
    }
    cryptoTransaction {
      transactionSignature
      walletFrom
      walletTo
      amount
      state
    }
    errors
  }
}
```

## 🎯 Example Values

### Order Details
```
Order ID: 25
Order Number: 3FZFMHOK5B73D4BD4AB4
Amount: 0.000017581 SOL
Platform Wallet: zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE
```

### Transaction on Solana
```
From: 3FZfmCwm8HhDxQCHRkni1e1SYoPQymG75hPfktjp27yU (user)
To: zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE (platform)
Amount: 0.000017581 SOL
Signature: 3jnzwgPuZJw6T7m4WBgHofg5dEULvkMgFni7aa72xvpuh9WmZd62TAnkcyNRJCvRqadXfd9kKrAo5rmY5J1WZTQU
```

### Verification
```ruby
PaymentVerificationService.verify_and_confirm_payment(
  order: order,
  transaction_signature: "3jnzwgPuZJw6T7m4...",
  sender_wallet: "3FZfmCwm8HhDxQCH..."
)

✅ Transaction found on blockchain
✅ Status: confirmed
✅ Amount: 0.000017581 SOL (matches order)
✅ To: zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE (correct)
✅ From: 3FZfmCwm8HhDxQCHRkni1e1SYoPQymG75hPfktjp27yU (correct)
✅ No duplicates found

→ Order status: pending → paid ✓
```

## 🛡️ Security Benefits

| Before | After |
|--------|-------|
| ❌ Trust client data | ✅ Verify on blockchain |
| ❌ Manual confirmation | ✅ Automatic verification |
| ❌ Possible fraud | ✅ On-chain proof required |
| ❌ Amount mismatches | ✅ Amount validated |
| ❌ Wrong wallet | ✅ Wallet validated |

## 🚨 Error Handling

```javascript
// Frontend retry logic for "not found" errors
async function confirmWithRetry(orderId, signature) {
  for (let i = 0; i < 3; i++) {
    try {
      const result = await confirmPayment(orderId, signature);

      if (result.verified) {
        return result; // ✅ Success
      }

      if (result.errors[0]?.includes('not found')) {
        await sleep(2000); // Wait for RPC indexing
        continue; // Retry
      }

      throw new Error(result.errors[0]); // ❌ Other error

    } catch (error) {
      if (i === 2) throw error; // Last attempt failed
    }
  }
}
```

## 📊 Verification Logs

All verifications are logged in `AuditLog`:

```ruby
action: 'payment_verified'
metadata: {
  order_number: "3FZFMHOK5B73D4BD4AB4",
  transaction_signature: "3jnzwgPuZJw...",
  wallet_from: "3FZfmCwm8HhD...",
  wallet_to: "zrq5sFgpDs8p...",
  amount: 0.000017581,
  verified_at: "2025-12-05 08:45:23 UTC"
}
```

## 🔧 Quick Test

```bash
# Test verification with a real order
rails runner "
order = Order.pending.last
result = PaymentVerificationService.verify_payment(
  order: order,
  transaction_signature: 'YOUR_TX_SIG',
  sender_wallet: order.user.wallet_address
)
puts result[:verified] ? '✅ Verified' : '❌ Failed'
puts result[:error] if result[:error]
"
```

## 🌐 Solana RPC Configuration

```bash
# .env file
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
PLATFORM_WALLET_ADDRESS=zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE
```

## 📁 Files

- **Service**: `app/services/payment_verification_service.rb`
- **Mutation**: `app/graphql/mutations/orders/confirm_payment.rb`
- **Full Guide**: `PAYMENT_VERIFICATION_GUIDE.md`
