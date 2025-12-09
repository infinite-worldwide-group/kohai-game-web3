# Purchase Game Credit Mutation Guide

## Overview

The `purchaseGameCredit` mutation allows authenticated users to purchase game credits using cryptocurrency (SOL, USDT, or USDC) on the Solana blockchain.

## Prerequisites

1. User must be authenticated (have a valid JWT token from `authenticateWallet`)
2. User must have sent payment to the platform wallet via their wallet app
3. Transaction must be confirmed on the blockchain

## GraphQL Mutation

```graphql
mutation {
  purchaseGameCredit(
    productItemId: ID!
    transactionSignature: String!
    gameAccountId: String!
    serverId: String
    inGameName: String
    additionalInfo: JSON
  ) {
    order {
      id
      orderNumber
      amount
      currency
      status
      userData
      createdAt
      cryptoTransaction {
        transactionSignature
        state
        confirmations
        blockTimestamp
      }
    }
    success
    message
    errors
  }
}
```

## Arguments

| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `productItemId` | ID | ✓ | ID of the TopupProductItem to purchase |
| `transactionSignature` | String | ✓ | Blockchain transaction signature from wallet |
| `gameAccountId` | String | ✓ | Game account ID where credits will be delivered |
| `serverId` | String | ✗ | Game server ID (if applicable, e.g., "2051" for Mobile Legends) |
| `inGameName` | String | ✗ | In-game character/player name |
| `additionalInfo` | JSON | ✗ | Additional game-specific data (e.g., zone_id, role_id) |

## Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `order` | Order | Created order object (null if failed) |
| `success` | Boolean | Whether the purchase was successful |
| `message` | String | Human-readable message |
| `errors` | [String] | Array of error messages (empty if successful) |

## Complete Purchase Flow

### Step 1: User Authenticates
```graphql
mutation {
  authenticateWallet(walletAddress: "9fZ8XwKzYvPQc5kLT7xM...") {
    user {
      id
      walletAddress
    }
    token
    errors
  }
}
```

**Response:**
```json
{
  "data": {
    "authenticateWallet": {
      "user": {
        "id": "1",
        "walletAddress": "9fZ8XwKzYvPQc5kLT7xM..."
      },
      "token": "eyJhbGciOiJIUzI1NiJ9...",
      "errors": []
    }
  }
}
```

Store the JWT token for subsequent requests.

### Step 2: User Sends Payment via Wallet

**Frontend triggers wallet app:**
```javascript
// Example with Solana wallet adapter
const connection = new Connection(rpcUrl);
const transaction = new Transaction().add(
  SystemProgram.transfer({
    fromPubkey: userWallet.publicKey,
    toPubkey: new PublicKey(PLATFORM_WALLET_ADDRESS),
    lamports: 0.05 * LAMPORTS_PER_SOL // Amount from product price
  })
);

const signature = await wallet.sendTransaction(transaction, connection);
await connection.confirmTransaction(signature);

console.log("Transaction signature:", signature);
```

### Step 3: Call purchaseGameCredit Mutation

```graphql
mutation {
  purchaseGameCredit(
    productItemId: "123"
    transactionSignature: "5j7s8K3w9DL2VhYc..."
    gameAccountId: "12345678"
    serverId: "2051"
    inGameName: "PlayerOne"
    additionalInfo: {
      zone_id: "Asia"
      role_id: "tank"
    }
  ) {
    order {
      id
      orderNumber
      amount
      currency
      status
      userData
      createdAt
      cryptoTransaction {
        transactionSignature
        state
        confirmations
        blockTimestamp
      }
    }
    success
    message
    errors
  }
}
```

**Success Response:**
```json
{
  "data": {
    "purchaseGameCredit": {
      "order": {
        "id": "456",
        "orderNumber": "ORD-1730000000-A1B2",
        "amount": 0.05,
        "currency": "SOL",
        "status": "paid",
        "userData": {
          "game_account_id": "12345678",
          "server_id": "2051",
          "in_game_name": "PlayerOne",
          "zone_id": "Asia",
          "role_id": "tank"
        },
        "createdAt": "2025-01-07T10:30:00Z",
        "cryptoTransaction": {
          "transactionSignature": "5j7s8K3w9DL2VhYc...",
          "state": "confirmed",
          "confirmations": 31,
          "blockTimestamp": "2025-01-07T10:30:00Z"
        }
      },
      "success": true,
      "message": "Game credit purchase successful! Order ORD-1730000000-A1B2 created.",
      "errors": []
    }
  }
}
```

## Error Handling

### 1. Transaction Not Found
```json
{
  "data": {
    "purchaseGameCredit": {
      "order": null,
      "success": false,
      "message": "Transaction not found on blockchain",
      "errors": ["Transaction not found on blockchain. Please ensure the transaction is confirmed."]
    }
  }
}
```

**Solution:** Wait for transaction confirmation and retry.

### 2. Invalid Transaction Amount
```json
{
  "data": {
    "purchaseGameCredit": {
      "order": null,
      "success": false,
      "message": "Transaction amount 0.03 SOL does not match expected 0.05 SOL",
      "errors": ["Transaction amount 0.03 SOL does not match expected 0.05 SOL"]
    }
  }
}
```

**Solution:** Send the correct amount matching the product price.

### 3. Wrong Sender Address
```json
{
  "data": {
    "purchaseGameCredit": {
      "order": null,
      "success": false,
      "message": "Transaction sender ABC123... does not match expected 9fZ8X...",
      "errors": ["Transaction sender ABC123... does not match expected 9fZ8X..."]
    }
  }
}
```

**Solution:** Use the same wallet address that was authenticated.

### 4. Duplicate Transaction
```json
{
  "data": {
    "purchaseGameCredit": {
      "order": null,
      "success": false,
      "message": "This transaction has already been used",
      "errors": ["This transaction signature has already been used for another order"]
    }
  }
}
```

**Solution:** Each transaction can only be used once. Send a new payment.

### 5. Product Not Available
```json
{
  "data": {
    "purchaseGameCredit": {
      "order": null,
      "success": false,
      "message": "This product is currently unavailable",
      "errors": ["Product is not available for purchase"]
    }
  }
}
```

**Solution:** Choose a different product or contact support.

### 6. Not Authenticated
```json
{
  "errors": [
    {
      "message": "You must be logged in to purchase game credits",
      "extensions": {
        "code": "AUTHENTICATION_ERROR"
      }
    }
  ]
}
```

**Solution:** Call `authenticateWallet` first and include JWT token in request headers.

## Frontend Implementation Example

```javascript
// 1. Authenticate wallet
async function authenticateWallet(walletAddress) {
  const response = await fetch('/graphql', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: `
        mutation($walletAddress: String!) {
          authenticateWallet(walletAddress: $walletAddress) {
            user { id, walletAddress }
            token
            errors
          }
        }
      `,
      variables: { walletAddress }
    })
  });

  const { data } = await response.json();

  if (data.authenticateWallet.token) {
    localStorage.setItem('authToken', data.authenticateWallet.token);
    return data.authenticateWallet.token;
  }

  throw new Error(data.authenticateWallet.errors.join(', '));
}

// 2. Send payment via wallet
async function sendPayment(amount, platformWallet) {
  const connection = new Connection(RPC_URL);
  const transaction = new Transaction().add(
    SystemProgram.transfer({
      fromPubkey: wallet.publicKey,
      toPubkey: new PublicKey(platformWallet),
      lamports: amount * LAMPORTS_PER_SOL
    })
  );

  const signature = await wallet.sendTransaction(transaction, connection);
  await connection.confirmTransaction(signature, 'confirmed');

  return signature;
}

// 3. Purchase game credit
async function purchaseGameCredit(productItemId, signature, gameAccountId) {
  const token = localStorage.getItem('authToken');

  const response = await fetch('/graphql', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      query: `
        mutation($input: PurchaseGameCreditInput!) {
          purchaseGameCredit(
            productItemId: $input.productItemId
            transactionSignature: $input.transactionSignature
            gameAccountId: $input.gameAccountId
            serverId: $input.serverId
            inGameName: $input.inGameName
          ) {
            order {
              id
              orderNumber
              status
              amount
            }
            success
            message
            errors
          }
        }
      `,
      variables: {
        input: {
          productItemId,
          transactionSignature: signature,
          gameAccountId,
          serverId: "2051",
          inGameName: "PlayerOne"
        }
      }
    })
  });

  const { data } = await response.json();

  if (data.purchaseGameCredit.success) {
    console.log('Purchase successful!', data.purchaseGameCredit.order);
    return data.purchaseGameCredit.order;
  } else {
    console.error('Purchase failed:', data.purchaseGameCredit.errors);
    throw new Error(data.purchaseGameCredit.message);
  }
}

// Complete flow
async function completePurchase(productItem, gameAccountId) {
  try {
    // 1. Authenticate
    const walletAddress = wallet.publicKey.toString();
    await authenticateWallet(walletAddress);

    // 2. Send payment
    const signature = await sendPayment(productItem.price, PLATFORM_WALLET);

    // 3. Create order
    const order = await purchaseGameCredit(
      productItem.id,
      signature,
      gameAccountId
    );

    alert(`Purchase successful! Order: ${order.orderNumber}`);

  } catch (error) {
    alert(`Purchase failed: ${error.message}`);
  }
}
```

## Backend Verification Process

When `purchaseGameCredit` is called, the backend:

1. **Validates Authentication** - Checks JWT token
2. **Finds Product** - Verifies product exists and is active
3. **Verifies Transaction** - Queries Solana blockchain via RPC:
   - Checks transaction exists and is confirmed
   - Validates sender = authenticated user's wallet
   - Validates receiver = platform wallet
   - Validates amount = product price
   - Checks minimum confirmations (1+)
4. **Creates Records** - In a database transaction:
   - Creates Order record
   - Creates CryptoTransaction record
   - Creates AuditLog record
   - Updates order status to 'paid'
5. **Enqueues Fulfillment** - Background job delivers credits via vendor API
6. **Returns Response** - Order details with success status

## Security Features

- ✓ JWT authentication required
- ✓ Transaction verified on-chain (not trusted from client)
- ✓ Sender wallet must match authenticated user
- ✓ Amount must match product price (within 0.0001 SOL tolerance)
- ✓ Transaction signature unique constraint (prevents double-spend)
- ✓ All actions logged in audit_logs table
- ✓ Database transaction ensures atomicity

## Next Steps After Purchase

1. **Order Status**: `pending` → `paid` (immediately after verification)
2. **Background Job**: VendorFulfillmentJob processes order
3. **Vendor API Call**: Credits sent to game account
4. **Order Status**: `paid` → `succeeded` (after successful delivery)
5. **User Notification**: Email/notification sent to user

## Query Order Status

```graphql
query {
  order(id: "456") {
    id
    orderNumber
    status
    amount
    currency
    createdAt
    cryptoTransaction {
      transactionSignature
      state
      confirmations
    }
  }
}
```

## Get All My Orders

```graphql
query {
  myOrders(limit: 20) {
    id
    orderNumber
    status
    amount
    currency
    createdAt
  }
}
```
