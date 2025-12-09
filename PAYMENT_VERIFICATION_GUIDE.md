# Payment Verification Guide

## Overview

Before confirming an order, the system now verifies the Solana transaction on-chain to ensure:
1. ✅ Transaction exists and is confirmed on Solana blockchain
2. ✅ Payment amount matches the order amount
3. ✅ Payment was sent to the correct platform wallet
4. ✅ Payment was sent from the user's wallet
5. ✅ Transaction signature is valid

## Payment Flow

### Step 1: User Creates Order (Checkout)

**GraphQL Mutation:**
```graphql
mutation TopupProductCheckout($input: TopupProductCheckoutInput!) {
  topupProductCheckout(input: $input) {
    topupProductCheckout {
      orderId
      orderNumber
      paymentAmount
      paymentCurrency
      walletTo
      priceUsdt
      priceMyr
      status
      expiresAt
    }
  }
}
```

**Response:**
```json
{
  "topupProductCheckout": {
    "orderId": "25",
    "orderNumber": "3FZFMHOK5B73D4BD4AB4",
    "paymentAmount": 0.000017581,
    "paymentCurrency": "SOL",
    "walletTo": "zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE",
    "priceUsdt": 0.00242131,
    "priceMyr": 0.01,
    "status": "pending",
    "expiresAt": "2025-12-05T09:30:00Z"
  }
}
```

### Step 2: User Sends Payment

User sends `paymentAmount` SOL to `walletTo` address using their Solana wallet (Phantom, Reown, etc.)

**Transaction Details:**
- **From**: User's wallet address
- **To**: `walletTo` (platform wallet)
- **Amount**: `paymentAmount` SOL
- **Network**: Solana Mainnet

The wallet will return a **transaction signature** after the transaction is sent.

### Step 3: Verify and Confirm Payment

**GraphQL Mutation:**
```graphql
mutation ConfirmPayment($orderId: ID!, $transactionSignature: String!) {
  confirmPayment(
    orderId: $orderId
    transactionSignature: $transactionSignature
  ) {
    order {
      id
      orderNumber
      status
      amount
      currency
      cryptoAmount
      cryptoCurrency
    }
    cryptoTransaction {
      id
      transactionSignature
      walletFrom
      walletTo
      amount
      token
      state
      verifiedAt
    }
    verified
    errors
  }
}
```

**Example Request:**
```json
{
  "orderId": "25",
  "transactionSignature": "3jnzwgPuZJw6T7m4WBgHofg5dEULvkMgFni7aa72xvpuh9WmZd62TAnkcyNRJCvRqadXfd9kKrAo5rmY5J1WZTQU"
}
```

**Success Response:**
```json
{
  "confirmPayment": {
    "order": {
      "id": "25",
      "orderNumber": "3FZFMHOK5B73D4BD4AB4",
      "status": "paid",
      "amount": 0.00242131,
      "currency": "USDT",
      "cryptoAmount": 0.000017581,
      "cryptoCurrency": "SOL"
    },
    "cryptoTransaction": {
      "id": "15",
      "transactionSignature": "3jnzwgPuZJw6T7m4WBgHofg5dEULvkMgFni7aa72xvpuh9WmZd62TAnkcyNRJCvRqadXfd9kKrAo5rmY5J1WZTQU",
      "walletFrom": "3FZfmCwm8HhDxQCHRkni1e1SYoPQymG75hPfktjp27yU",
      "walletTo": "zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE",
      "amount": 0.000017581,
      "token": "SOL",
      "state": "confirmed",
      "verifiedAt": "2025-12-05T08:45:23Z"
    },
    "verified": true,
    "errors": []
  }
}
```

**Error Response (Transaction Not Found):**
```json
{
  "confirmPayment": {
    "order": {
      "id": "25",
      "status": "pending"
    },
    "cryptoTransaction": null,
    "verified": false,
    "errors": [
      "Transaction not found on blockchain. Please wait a moment and try again."
    ]
  }
}
```

**Error Response (Amount Mismatch):**
```json
{
  "confirmPayment": {
    "order": {
      "id": "25",
      "status": "pending"
    },
    "cryptoTransaction": null,
    "verified": false,
    "errors": [
      "Transaction amount 0.000010000 SOL is less than expected 0.000017581 SOL"
    ]
  }
}
```

**Error Response (Wrong Receiver):**
```json
{
  "confirmPayment": {
    "order": {
      "id": "25",
      "status": "pending"
    },
    "cryptoTransaction": null,
    "verified": false,
    "errors": [
      "Transaction receiver WRONG_ADDRESS does not match expected zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE"
    ]
  }
}
```

## Verification Process

The `PaymentVerificationService` performs these checks:

### 1. Transaction Existence
```ruby
# Fetches transaction from Solana blockchain
SolanaTransactionService.verify_transaction(
  signature: transaction_signature,
  expected_amount: order.crypto_amount,
  expected_receiver: platform_wallet,
  expected_sender: user.wallet_address
)
```

### 2. Transaction Status
- Must be `confirmed` or `finalized` on Solana
- Must have at least 1 confirmation
- Must not have errors

### 3. Amount Verification
```ruby
# Allows 1% tolerance for price fluctuations
tolerance = 0.01
if amount_paid < (expected_amount - tolerance)
  raise InvalidTransaction
end
```

User can **overpay**, but **cannot underpay** (beyond 1% tolerance).

### 4. Wallet Verification
- **From Wallet**: Must match user's wallet address
- **To Wallet**: Must match platform wallet (`PLATFORM_WALLET_ADDRESS` env variable)

### 5. Duplicate Prevention
- Checks if transaction signature already exists
- Checks if order already has a payment
- Prevents double-spending

## Service Methods

### 1. `verify_payment` - Verify Only
```ruby
result = PaymentVerificationService.verify_payment(
  order: order,
  transaction_signature: signature,
  sender_wallet: user.wallet_address
)
# Returns: { success: true/false, verified: true/false, transaction_details: {...} }
```

### 2. `verify_and_record_payment` - Verify + Record
```ruby
result = PaymentVerificationService.verify_and_record_payment(
  order: order,
  transaction_signature: signature,
  sender_wallet: user.wallet_address
)
# Returns: { success: true/false, crypto_transaction: CryptoTransaction, ... }
```

### 3. `verify_and_confirm_payment` - Complete Flow
```ruby
result = PaymentVerificationService.verify_and_confirm_payment(
  order: order,
  transaction_signature: signature,
  sender_wallet: user.wallet_address
)
# Returns: { success: true/false, paid: true/false, order: Order, ... }
```

## Frontend Implementation Example

### React/TypeScript with Solana Wallet

```typescript
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import { LAMPORTS_PER_SOL, PublicKey, SystemProgram, Transaction } from '@solana/web3.js';

async function handlePayment(orderData) {
  const { connection } = useConnection();
  const { publicKey, sendTransaction } = useWallet();

  if (!publicKey) {
    throw new Error('Wallet not connected');
  }

  try {
    // 1. Create transaction
    const transaction = new Transaction().add(
      SystemProgram.transfer({
        fromPubkey: publicKey,
        toPubkey: new PublicKey(orderData.walletTo),
        lamports: orderData.paymentAmount * LAMPORTS_PER_SOL,
      })
    );

    // 2. Send transaction
    const signature = await sendTransaction(transaction, connection);
    console.log('Transaction sent:', signature);

    // 3. Wait for confirmation
    await connection.confirmTransaction(signature, 'confirmed');
    console.log('Transaction confirmed:', signature);

    // 4. Verify and confirm payment with backend
    const result = await confirmPaymentMutation({
      variables: {
        orderId: orderData.orderId,
        transactionSignature: signature,
      },
    });

    if (result.data.confirmPayment.verified) {
      console.log('Payment verified!');
      // Redirect to success page
    } else {
      console.error('Verification failed:', result.data.confirmPayment.errors);
    }

  } catch (error) {
    console.error('Payment failed:', error);
  }
}
```

## Error Handling

### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Transaction not found" | Transaction not yet indexed by RPC | Wait 2-5 seconds and retry |
| "Insufficient confirmations" | Transaction pending | Wait for confirmation |
| "Amount mismatch" | Wrong amount sent | Send correct amount |
| "Wrong receiver" | Sent to wrong address | Check `walletTo` in checkout response |
| "Already used" | Transaction already recorded | Can't reuse same transaction |
| "Order not pending" | Order already paid/cancelled | Check order status |

### Retry Logic

```javascript
async function confirmPaymentWithRetry(orderId, signature, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    const result = await confirmPayment(orderId, signature);

    if (result.verified) {
      return result; // Success
    }

    if (result.errors[0]?.includes('not found')) {
      // Transaction not indexed yet, wait and retry
      await sleep(2000);
      continue;
    }

    // Other errors, don't retry
    throw new Error(result.errors[0]);
  }

  throw new Error('Payment verification timeout');
}
```

## Security Features

### 1. On-Chain Verification
- All transactions verified on Solana blockchain
- No reliance on client-side data
- RPC endpoint: `https://api.mainnet-beta.solana.com`

### 2. Duplicate Prevention
- Transaction signature uniqueness enforced
- One transaction per order
- Database constraints prevent double-spending

### 3. Amount Tolerance
- 1% tolerance for price fluctuations
- Overpayment allowed (user's choice)
- Underpayment rejected (protects vendor)

### 4. Audit Logging
All payment verifications are logged:
```ruby
AuditLog.create!(
  user: order.user,
  action: 'payment_verified',
  auditable: order,
  metadata: {
    transaction_signature: signature,
    wallet_from: user.wallet,
    wallet_to: platform.wallet,
    amount: verified_amount,
    verified_at: timestamp
  }
)
```

## Testing

### Test with Devnet

1. Set `SOLANA_RPC_URL=https://api.devnet.solana.com` in `.env`
2. Use devnet SOL (free from faucet)
3. Test transactions with devnet wallet

### Test Order Verification

```bash
rails runner "
order = Order.find(ORDER_ID)
result = PaymentVerificationService.verify_payment(
  order: order,
  transaction_signature: 'YOUR_TX_SIGNATURE',
  sender_wallet: 'USER_WALLET_ADDRESS'
)
puts result.inspect
"
```

## Environment Variables

```bash
# Solana RPC endpoint
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com

# Platform wallet to receive payments
PLATFORM_WALLET_ADDRESS=zrq5sFgpDs8pEZDcPRX1u3rFDCD6JiPAWSNLQFtcEcE
```

## Files Created

1. `app/services/payment_verification_service.rb` - Payment verification logic
2. `app/graphql/mutations/orders/confirm_payment.rb` - GraphQL mutation
3. `app/graphql/types/mutation_type.rb` - Added confirmPayment field

## Related Services

- `SolanaTransactionService` - Blockchain interaction
- `TopupProductService` - Order checkout
- `OrderService` - Order management
- `CurrencyConversionService` - Price conversion
