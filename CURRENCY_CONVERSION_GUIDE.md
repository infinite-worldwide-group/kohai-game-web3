# Currency Conversion Guide

## Overview

Orders are displayed in **local/fiat currency** (USD, MYR, etc.) but payments are made in **cryptocurrency** (SOL) through Reown wallet.

## How It Works

### 1. Product Pricing
Products are priced in fiat currency (e.g., $5.56 USD):
```ruby
TopupProductItem.create!(
  name: "Steam Wallet Code RM5 MY",
  price: 5.56,
  currency: "USD"  # Fiat currency
)
```

### 2. Order Creation Flow

```
User sees: $5.56 USD (with 1% VIP discount = $5.50 USD)
           ↓
Backend converts: $5.50 USD → 0.0388 SOL (at current rate)
           ↓
Reown shows: Pay 0.0388 SOL
           ↓
Order stores both:
  - amount: 5.50 (USD) - for display/accounting
  - crypto_amount: 0.0388 (SOL) - actual payment
```

### 3. Frontend GraphQL Query

```graphql
query GetProducts {
  topupProducts {
    items {
      id
      name
      price      # e.g., 5.56
      currency   # e.g., "USD"
    }
  }
}
```

### 4. Calculate SOL Amount for Reown

**Option A: Let backend handle conversion (recommended)**

The backend automatically converts USD to SOL when creating the order. You just need to show the user both amounts before payment:

```javascript
// 1. Get product
const product = { id: "1", name: "Steam Code", price: 5.56, currency: "USD" }

// 2. Get SOL price for display (optional - just to show user before payment)
const solPrice = await fetch('https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd')
  .then(r => r.json())
  .then(data => data.solana.usd)

const solAmount = product.price / solPrice

// 3. Show user
alert(`You will pay ${solAmount.toFixed(9)} SOL (≈ $${product.price} ${product.currency})`)

// 4. User pays via Reown
const signature = await reownWallet.pay({
  to: platformWallet,
  amount: solAmount,  // SOL amount
  token: 'SOL'
})

// 5. Create order (backend verifies the SOL amount matches)
const order = await createOrder(product.id, signature)
```

**Option B: Add a query to get SOL amount from backend**

If you want the backend to calculate the exact SOL amount before payment:

```graphql
query CalculatePrice($productId: ID!) {
  calculateOrderPrice(productItemId: $productId) {
    fiatAmount      # 5.56
    fiatCurrency    # "USD"
    cryptoAmount    # 0.039185284
    cryptoCurrency  # "SOL"
    discount        # 0.06 (if VIP)
    tierDiscount    # "1%" (if VIP)
  }
}
```

### 5. Create Order Mutation

```graphql
mutation CreateOrder($productId: ID!, $signature: String!) {
  createOrder(
    topupProductItemId: $productId
    transactionSignature: $signature
  ) {
    order {
      id
      orderNumber

      # Fiat amounts (for display to user)
      amount           # 5.50 USD
      originalAmount   # 5.56 USD
      currency         # "USD"

      # Crypto amounts (what was actually paid)
      cryptoAmount     # 0.0388 SOL
      cryptoCurrency   # "SOL"

      # Discount info
      discountAmount   # 0.06 USD
      discountPercent  # 1.0
      tierAtPurchase   # "Elite"

      status
      createdAt
    }
    errors
  }
}
```

### 6. Display Order to User

```javascript
// Show in user's dashboard/receipts
function OrderCard({ order }) {
  return (
    <div>
      <h3>Order {order.orderNumber}</h3>

      {/* Show fiat amount prominently */}
      <p className="price">
        ${order.amount} {order.currency}
      </p>

      {/* Show discount if applicable */}
      {order.discountAmount > 0 && (
        <p className="discount">
          Original: ${order.originalAmount}
          <br />
          You saved: ${order.discountAmount} ({order.discountPercent}%)
          <br />
          VIP Tier: {order.tierAtPurchase}
        </p>
      )}

      {/* Show crypto payment details (collapsed/small) */}
      <details>
        <summary>Payment Details</summary>
        <p>
          Paid: {order.cryptoAmount} {order.cryptoCurrency}
          <br />
          Tx: {order.cryptoTransaction.transactionSignature}
        </p>
      </details>
    </div>
  )
}
```

## Complete Frontend Example

```javascript
import { createAppKit } from '@reown/appkit'
import { SolanaAdapter } from '@reown/appkit-adapter-solana'

// Initialize Reown
const appKit = createAppKit({
  adapters: [new SolanaAdapter()],
  projectId: 'YOUR_REOWN_PROJECT_ID',
  networks: [solana, solanaDevnet]
})

async function purchaseProduct(product) {
  try {
    // 1. Connect wallet
    await appKit.open()
    const userWallet = appKit.getAddress()

    // 2. Authenticate with backend
    const { token } = await authenticateWallet(userWallet)
    localStorage.setItem('authToken', token)

    // 3. Calculate SOL amount
    const solPrice = await getSolPrice()
    const solAmount = product.price / solPrice

    // 4. Show confirmation
    const confirmed = confirm(
      `Purchase ${product.name}\n\n` +
      `Price: $${product.price} ${product.currency}\n` +
      `You will pay: ${solAmount.toFixed(9)} SOL\n\n` +
      `Proceed?`
    )

    if (!confirmed) return

    // 5. Send payment via Reown
    const signature = await sendSolPayment(solAmount, PLATFORM_WALLET)

    // 6. Create order on backend
    const order = await createOrder(product.id, signature)

    // 7. Show success
    alert(
      `✅ Purchase successful!\n\n` +
      `Order: ${order.orderNumber}\n` +
      `Amount: $${order.amount} ${order.currency}\n` +
      `Paid: ${order.cryptoAmount} ${order.cryptoCurrency}`
    )

    return order

  } catch (error) {
    alert(`Purchase failed: ${error.message}`)
  }
}

async function sendSolPayment(amount, toAddress) {
  const connection = new Connection('https://api.devnet.solana.com')
  const fromAddress = appKit.getAddress()

  const transaction = new Transaction().add(
    SystemProgram.transfer({
      fromPubkey: new PublicKey(fromAddress),
      toPubkey: new PublicKey(toAddress),
      lamports: amount * LAMPORTS_PER_SOL
    })
  )

  const signature = await appKit.sendTransaction(transaction, connection)
  await connection.confirmTransaction(signature, 'confirmed')

  return signature
}

async function createOrder(productId, signature) {
  const token = localStorage.getItem('authToken')

  const response = await fetch('/graphql', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      query: `
        mutation($productId: ID!, $signature: String!) {
          createOrder(
            topupProductItemId: $productId
            transactionSignature: $signature
          ) {
            order {
              id
              orderNumber
              amount
              currency
              cryptoAmount
              cryptoCurrency
              discountAmount
              discountPercent
              tierAtPurchase
            }
            errors
          }
        }
      `,
      variables: { productId, signature }
    })
  })

  const { data } = await response.json()

  if (data.createOrder.errors.length > 0) {
    throw new Error(data.createOrder.errors.join(', '))
  }

  return data.createOrder.order
}
```

## Currency Conversion Service

The backend uses CoinGecko API to get real-time SOL prices (cached for 5 minutes):

```ruby
# Get current SOL price
sol_price = CurrencyConversionService.get_sol_price_usd
# => 141.89

# Convert USD to SOL
sol_amount = CurrencyConversionService.usd_to_sol(5.56)
# => 0.039185284

# Convert SOL to USD
usd_amount = CurrencyConversionService.sol_to_usd(0.039)
# => 5.53
```

## Summary

| Field | Purpose | Example | Where to show |
|-------|---------|---------|---------------|
| `amount` | Fiat price (display) | $5.56 USD | Product page, order history, receipts |
| `crypto_amount` | SOL paid (actual) | 0.0388 SOL | Reown wallet, transaction details |
| `currency` | Fiat currency | "USD" | All user-facing displays |
| `crypto_currency` | Crypto used | "SOL" | Payment confirmation, blockchain explorer |

**Key Points:**
- ✅ Users see prices in familiar fiat currency (USD, MYR, etc.)
- ✅ Reown wallet shows SOL amount for payment
- ✅ Backend handles conversion automatically
- ✅ Orders store both amounts for accounting and display
- ✅ VIP discounts applied to fiat amount, then converted to SOL

## Testing with Simulated Transactions

For testing, use `sim_` prefix in transaction signatures:

```javascript
const signature = `sim_${Date.now()}_test`
await createOrder(productId, signature)
```

This bypasses blockchain verification while testing the currency conversion flow.
