# Database & Flow Diagrams - Kohai Game Web3 (Crypto-Only)


## 1. Entity Relationship Diagram (ERD)
`
```

┌─────────────────────────────────────────────────────────────────────────────┐
│                            USER (Central Entity)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ id                                                                          │
│ wallet_address (Solana - primary identifier for crypto payments)            │
│ email (optional)                                                            │
│ created_at, updated_at                                                      │
└────────────┬────────────────────────────┬───────────────────────────────────┘
             │                            │
             │ has_many                   │ has_many
             │                            │
             ▼                            ▼
    ┌──────────────┐           ┌─────────────────┐
    │    ORDER     │           │  GAME_ACCOUNT   │
    ├──────────────┤           ├─────────────────┤
    │ user_id      │           │ user_id         │
    │ topup_       │           │ game_id         │
    │  product_    │           │ account_id      │
    │  item_id ────┼──────┐    │ server_id       │
    │ game_        │      │    │ in_game_name    │
    │  account_id ─┼──────┼───►│ approve         │
    │ fiat_        │      │    └─────────────────┘
    │  currency_id─┼──┐   │
    │ order_number │  │   │
    │ amount       │  │   │
    │ currency     │  │   │
    │ status(AASM) │  │   │
    │ order_type   │  │   │
    │ user_data(jsonb)│   │
    │ metadata(jsonb) │   │  ← system or internal metadata
    └──────┬───────┘  │   │
           │          │   │
           │ has_one  │   │ belongs_to (optional)
           ▼          ▼   │
    ┌────────────────────────────────────────┐
    │          CRYPTO_TRANSACTION            │    ┌──────────────────┐
    ├────────────────────────────────────────┤    │ FIAT_CURRENCY    │
    │ order_id                               │    ├──────────────────┤
    │ transaction_signature (unique)         │◄───│ code (USDT,USDC) │
    │ wallet_from                            │    │ name, symbol     │
    │ wallet_to                              │    │ token_mint       │
    │ amount                                 │    │ decimals (6/9)   │
    │ token ("SOL","USDT","USDC")            │    │ network (solana) │
    │ network ("solana")                     │    │ usd_rate         │
    │ decimals (9 for SOL, 6 for USDT)       │    │ is_active        │
    │ transaction_type ("payment","refund")  │    │ is_default       │
    │ direction ("inbound","outbound")       │    │ metadata(jsonb)  │
    │ state (AASM)                           │    └──────────────────┘
    │ confirmations, block_number            │
    │ block_timestamp, gas_fee               │
    │ verified_at                            │
    │ created_at, updated_at                 │
    └────────────────────────────────────────┘
                          │
                          │ belongs_to
                          ▼
                 ┌──────────────────────┐
                 │ TOPUP_PRODUCT_ITEM   │
                 ├──────────────────────┤
                 │ topup_product_id     │
                 │ name, price          │
                 │ origin_id, active    │
                 │ icon                 │
                 └────────┬─────────────┘
                          │
                          │ belongs_to
                          ▼
                 ┌──────────────────┐
                 │  TOPUP_PRODUCT   │
                 ├──────────────────┤
                 │ title, slug      │
                 │ is_active        │
                 │ category, code   │
                 │ user_input(jsonb)│
                 │ vendor_id        │
                 └──────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         SUPPORTING ENTITIES                                 │
└─────────────────────────────────────────────────────────────────────────────┘

        ┌────────────────────────────┐
        │     AUDIT_LOG              │
        ├────────────────────────────┤
        │ user_id                    │
        │ action                     │
        │ auditable ⟲                │
        │ old_values, new_values     │
        │ ip_address                 │
        │ user_agent                 │
        │ platform                   │
        │ referrer                   │
        └────────────────────────────┘

        ┌────────────────────────────┐
        │ VENDOR_TRANSACTION_LOGS    │
        ├────────────────────────────┤
        │ order_id                   │
        │ vendor_name                │
        │ request_body               │
        │ response_body              │
        │ status ("success","fail")  │
        │ retry_count                │
        │ executed_at                │
        └────────────────────────────┘

        ┌────────────────────────────┐
        │ VERIFICATION_CACHE         │
        ├────────────────────────────┤
        │ transaction_signature      │
        │ last_verified_at           │
        │ verification_status        │
        │ confirmations              │
        └────────────────────────────┘

⟲ = Polymorphic Association

REMOVED FROM ORIGINAL DESIGN:
✗ FiatWallet (No fiat balance)
✗ FiatTransaction (Crypto-only)
✗ RefundOrder (Refunds handled manually)
✗ PlatformWallet (replaced by wallet_to in CryptoTransaction)

```

---

## 2. Crypto Purchase Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CRYPTO-ONLY PURCHASE FLOW                                │
└─────────────────────────────────────────────────────────────────────────────┘

STEP 1: USER LOGIN (Connect Wallet)
┌────────────────────────────────────────────────────────────────────────┐
│  Frontend: User connects wallet via wallet app                        │
│  - Wallet connection established                                      │
│  - Wallet address captured from wallet                                │
│                                                                        │
│  GraphQL Mutation:                                                     │
│  mutation {                                                            │
│    authenticateWallet(                                                 │
│      walletAddress: "9fZ8X..."                                         │
│    ) {                                                                 │
│      user { id, walletAddress }                                        │
│      token                                                             │
│      errors                                                            │
│    }                                                                   │
│  }                                                                     │
│                                                                        │
│  Backend Processing:                                                   │
│  - User.find_or_create_by!(wallet_address: wallet_address)            │
│  - JWT token = SolanaAuthService.generate_token(user)                 │
│  - AuditLog.create(action: 'wallet_connection', user_id: user.id)     │
│                                                                        │
│  Database Changes:                                                     │
│  users:                                                                │
│    id: 1                                                               │
│    wallet_address: "9fZ8X..."                                          │
│    created_at: 2025-01-07                                              │
│                                                                        │
│  Result: User authenticated, JWT token stored in frontend              │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼

STEP 2: BROWSE PRODUCTS
┌────────────────────────────────────────────────────────────────────────┐
│  Frontend: User browses game credit products                          │
│                                                                        │
│  GraphQL Query (if available):                                         │
│  query {                                                               │
│    topupProducts(isActive: true) {                                     │
│      id, title, category                                               │
│      items {                                                           │
│        id, name, price                                                 │
│      }                                                                 │
│    }                                                                   │
│  }                                                                     │
│                                                                        │
│  OR Backend API call:                                                  │
│  GET /api/topup_products                                               │
│                                                                        │
│  Database Query:                                                       │
│  TopupProduct.where(is_active: true)                                   │
│               .includes(:topup_product_items)                          │
│               .where(topup_product_items: { active: true })            │
│                                                                        │
│  Display Example:                                                      │
│  - "500 ML Diamonds - 0.05 SOL"                                        │
│  - "1000 ML Diamonds - 0.10 SOL"                                       │
│                                                                        │
│  User selects: TopupProductItem ID: 123 (500 Diamonds, 0.05 SOL)     │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼

STEP 3: CREATE ORDER (User Initiates Purchase)
┌────────────────────────────────────────────────────────────────────────┐
│  Frontend: User clicks "Buy Now" button                               │
│  - User initiates order for selected product                          │
│  - Frontend fetches platform wallet from ENV/config                   │
│  - Prepare transaction details:                                       │
│    • To: PLATFORM_WALLET_ADDRESS (e.g., "4Ya2x...")                   │
│    • Amount: 0.05 SOL (from product item price)                       │
│    • Token: SOL (native) or SPL token (USDT/USDC)                     │
│                                                                        │
│  Frontend triggers wallet app to open payment dialog                  │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼

STEP 4: USER AUTHORIZES PAYMENT (Wallet App)
┌────────────────────────────────────────────────────────────────────────┐
│  Wallet App Opens Payment Dialog                                      │
│  - Payment Details Shown:                                              │
│    From: 9fZ8X... (user's wallet)                                      │
│    To: 4Ya2x... (platform wallet)                                      │
│    Amount: 0.05 SOL                                                    │
│    Network Fee: ~0.000005 SOL                                          │
│                                                                        │
│  User clicks "Approve"                                                 │
│  - Transaction signed with private key in wallet                      │
│  - Transaction broadcast to Solana blockchain                         │
│  - Blockchain returns transaction signature                           │
│                                                                        │
│  Frontend receives:                                                    │
│    signature: "5j7s8K3w9DL2Vh..."                                      │
│                                                                        │
│  Blockchain State:                                                     │
│    Transaction confirmed on Solana                                     │
│    - From: 9fZ8X... (user)                                             │
│    - To: 4Ya2x... (platform)                                           │
│    - Amount: 50000000 lamports (0.05 SOL)                              │
│    - Fee: 5000 lamports                                                │
│    - Confirmations: 1+                                                 │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼

STEP 5: BACKEND VERIFIES PAYMENT & CREATES ORDER RECORD
┌────────────────────────────────────────────────────────────────────────┐
│  Frontend: Calls createOrder mutation                                 │
│                                                                        │
│  GraphQL Mutation:                                                     │
│  mutation {                                                            │
│    createOrder(                                                        │
│      topupProductItemId: "123"                                         │
│      transactionSignature: "5j7s8K3w9DL2Vh..."                         │
│      userData: {                                                       │
│        game_account_id: "12345678",                                    │
│        server_id: "2051",                                              │
│        in_game_name: "PlayerOne"                                       │
│      }                                                                 │
│    ) {                                                                 │
│      order {                                                           │
│        id, orderNumber, amount, status                                 │
│        cryptoTransaction { transactionSignature, state }               │
│      }                                                                 │
│      errors                                                            │
│    }                                                                   │
│  }                                                                     │
│                                                                        │
│  Backend Processing:                                                   │
│  1. Require authentication (JWT token validation)                     │
│  2. Find TopupProductItem (id: 123)                                    │
│  3. Verify transaction on Solana blockchain:                          │
│     SolanaTransactionService.verify_transaction(                       │
│       signature: "5j7s8K3w9DL2Vh...",                                  │
│       expected_amount: 0.05,                                           │
│       expected_receiver: "4Ya2x...",                                   │
│       expected_sender: "9fZ8X..." # current_user.wallet_address        │
│     )                                                                  │
│     ↓ Queries Solana RPC: getTransaction                               │
│     ↓ Validates: amount, from, to, confirmations                       │
│                                                                        │
│  4. Create records in database transaction:                           │
│                                                                        │
│     orders table:                                                      │
│       id: 456                                                          │
│       user_id: 1                                                       │
│       topup_product_item_id: 123                                       │
│       fiat_currency_id: NULL (for SOL) or 1 (for USDT)                │
│       order_number: "ORD-1730000000-A1B2"                              │
│       amount: 0.05                                                     │
│       currency: "SOL"                                                  │
│       status: "pending" → "paid" (via Order.pay!)                      │
│       order_type: "topup"                                              │
│       user_data: {"game_account_id": "12345678", ...}                  │
│       created_at: 2025-01-07                                           │
│                                                                        │
│     crypto_transactions table:                                         │
│       id: 789                                                          │
│       order_id: 456                                                    │
│       transaction_signature: "5j7s8K3w9DL2Vh..." (UNIQUE)              │
│       wallet_from: "9fZ8X..."                                          │
│       wallet_to: "4Ya2x..."                                            │
│       amount: 0.05                                                     │
│       token: "SOL"                                                     │
│       network: "solana"                                                │
│       decimals: 9                                                      │
│       transaction_type: "payment"                                      │
│       direction: "inbound"                                             │
│       state: "confirmed"                                               │
│       confirmations: 31                                                │
│       block_number: 123456789                                          │
│       block_timestamp: 2025-01-07 10:30:00                             │
│       gas_fee: 0.000005                                                │
│       verified_at: 2025-01-07 10:30:15                                 │
│                                                                        │
│     audit_logs table:                                                  │
│       user_id: 1                                                       │
│       action: "order_created"                                          │
│       auditable_type: "Order"                                          │
│       auditable_id: 456                                                │
│       metadata: {order_number: "ORD-...", amount: 0.05, ...}           │
│                                                                        │
│  5. Call Order.pay! (AASM state transition: pending → paid)           │
│                                                                        │
│  Result: Order created successfully                                    │
│          Frontend receives order with status "paid"                    │
└────────────┬───────────────────────────────────────────────────────────┘
             │
             ▼

STEP 6: VENDOR DELIVERY
┌────────────────────────────────────────────┐
│  Background Job: Vendor fulfillment        │
│  - Call vendor API (Moogold, etc.)         │
│  - Provide: game_account, product_id       │
│                                            │
│  VendorTransactionLog.create!(             │
│    order_id: order.id,                     │
│    vendor_name: "moogold",                 │
│    request_body: {...},                    │
│    response_body: {...},                   │
│    status: "success"                       │
│  )                                         │
│                                            │
│  Success: Order.success!                   │
│  Failure: Order.fail! (manual refund)      │
└────────────┬───────────────────────────────┘
             ▼
┌────────────────────────────────────────────┐
│ COMPLETED                                  │
│  - User receives game credits              │
│  - Order status: succeeded                 │
│  - Email notification sent                 │
└────────────────────────────────────────────┘

```

---

## 3. GraphQL API Schema

### Available Mutations

```graphql
type Mutation {
  # Authentication
  authenticateWallet(
    walletAddress: String!
    signature: String      # Optional - for secure mode
    message: String         # Optional - for secure mode
  ): AuthenticateWalletPayload!

  # Purchase Management
  purchaseGameCredit(
    productItemId: ID!
    transactionSignature: String!
    gameAccountId: String!
    serverId: String        # Optional - game server ID
    inGameName: String      # Optional - character name
    additionalInfo: JSON    # Optional - extra game data
  ): PurchaseGameCreditPayload!

  # Order Management (Legacy)
  createOrder(
    topupProductItemId: ID!
    transactionSignature: String!
    userData: JSON          # Optional - game account info
  ): CreateOrderPayload!
}

type AuthenticateWalletPayload {
  user: User
  token: String            # JWT token for authentication
  errors: [String!]!
}

type PurchaseGameCreditPayload {
  order: Order
  success: Boolean!
  message: String
  errors: [String!]!
}

type CreateOrderPayload {
  order: Order
  errors: [String!]!
}
```

### Available Queries

```graphql
type Query {
  # User queries
  currentUser: User

  # Order queries
  order(id: ID!): Order
  myOrders(limit: Int = 20): [Order!]!

  # Transaction status
  transactionStatus(signature: String!): TransactionStatus
}

type User {
  id: ID!
  walletAddress: String!
  email: String
  createdAt: ISO8601DateTime!
  orders: [Order!]!
}

type Order {
  id: ID!
  orderNumber: String!
  amount: Float!
  currency: String!        # "SOL", "USDT", "USDC"
  status: String!          # "pending", "paid", "succeeded", "failed", "cancelled"
  orderType: String!       # "topup"
  userData: JSON
  metadata: JSON
  createdAt: ISO8601DateTime!
  updatedAt: ISO8601DateTime!

  user: User!
  cryptoTransaction: CryptoTransaction
}

type CryptoTransaction {
  id: ID!
  transactionSignature: String!
  walletFrom: String!
  walletTo: String!
  amount: Float!
  token: String!           # "SOL", "USDT", "USDC"
  network: String!         # "solana"
  decimals: Int!           # 9 for SOL, 6 for USDT/USDC
  transactionType: String! # "payment", "refund"
  direction: String!       # "inbound", "outbound"
  state: String!           # "pending", "confirmed", "failed"
  confirmations: Int!
  blockNumber: Int
  blockTimestamp: ISO8601DateTime
  gasFee: Float
  verifiedAt: ISO8601DateTime
  createdAt: ISO8601DateTime!
}

type TransactionStatus {
  signature: String!
  status: String!          # "not_found", "pending", "confirmed", "failed"
  confirmations: Int!
  error: String
}
```

### Example GraphQL Requests

**1. Authenticate Wallet (Simple Mode)**
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

**2. Purchase Game Credit (Recommended)**
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
      cryptoTransaction {
        transactionSignature
        state
        confirmations
      }
    }
    success
    message
    errors
  }
}
```

**3. Create Order (Legacy)**
```graphql
mutation {
  createOrder(
    topupProductItemId: "123"
    transactionSignature: "5j7s8K3w9DL2VhYc..."
    userData: {
      game_account_id: "12345678"
      server_id: "2051"
      in_game_name: "PlayerOne"
    }
  ) {
    order {
      id
      orderNumber
      amount
      currency
      status
      cryptoTransaction {
        transactionSignature
        state
        confirmations
      }
    }
    errors
  }
}
```

**4. Get Current User**
```graphql
query {
  currentUser {
    id
    walletAddress
    email
  }
}
```

**5. Get My Orders**
```graphql
query {
  myOrders(limit: 10) {
    id
    orderNumber
    amount
    currency
    status
    createdAt
    cryptoTransaction {
      transactionSignature
      state
    }
  }
}
```

**6. Check Transaction Status**
```graphql
query {
  transactionStatus(signature: "5j7s8K3w9DL2VhYc...") {
    signature
    status
    confirmations
    error
  }
}
```

---

## 4. State Machine Diagrams

### A. Order State Machine (AASM)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ORDER STATUS FLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

                            ┌─────────┐
                            │ PENDING │ (initial state)
                            └────┬────┘
                                 │
                 ┌───────────────┼───────────────┐
                 │               │               │
            pay! │          cancel!│         success!
                 │               │               │
                 ▼               ▼               ▼
            ┌────────┐      ┌──────────┐   ┌───────────┐
            │  PAID  │      │CANCELLED │   │ SUCCEEDED │
            └───┬────┘      └──────────┘   └───────────┘
                │
         ┌──────┴──────┐
         │             │
    complete!       fail!
         │             │
         ▼             ▼
    ┌──────────┐  ┌────────┐
    │COMPLETED │  │ FAILED │ (manual refund by admin)
    └──────────┘  └────────┘

Events:
- pay!      : Payment verified on blockchain
- success!  : Credits delivered successfully
- fail!     : Delivery failed (requires manual refund)
- cancel!   : User cancellation before payment
- complete! : Final completion state
```

### B. CryptoTransaction State Machine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   CRYPTO TRANSACTION STATE FLOW                              │
└─────────────────────────────────────────────────────────────────────────────┘

                         ┌─────────┐
                         │ PENDING │ (Transaction submitted)
                         └────┬────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
         confirm!         fail!          expire!
        (verified        (invalid        (timeout)
         on-chain)       signature)
              │               │               │
              ▼               ▼               ▼
         ┌──────────┐    ┌────────┐    ┌─────────┐
         │CONFIRMED │    │ FAILED │    │ EXPIRED │
         └──────────┘    └────────┘    └─────────┘
              │
              └──> Order.pay! triggered
                   (order status: pending → paid)

States:
- pending: Transaction signature received, awaiting verification
- confirmed: Verified on Solana blockchain with sufficient confirmations
- failed: Invalid signature or insufficient amount
- expired: Verification timeout (no transaction found)

Note: Refunds are handled manually by admin for failed orders
```

---

## 5. Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SYSTEM ARCHITECTURE                                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                    FRONTEND (Web App)                      │
├────────────────────────────────────────────────────────────┤
│  • User Interface (Product Browse, Checkout)               │
│  • Wallet Connection (User authenticates via wallet)       │
│  • Payment Authorization (User approves transactions)      │
│  • GraphQL Client (Communicates with backend API)          │
└────────────────────┬───────────────────────────────────────┘
                     │
                     │ GraphQL API Calls
                     │ (authenticateWallet, createOrder, myOrders, etc.)
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│                   RAILS BACKEND API                        │
├────────────────────────────────────────────────────────────┤
│  GraphQL API:                                              │
│    • Mutations: authenticateWallet, createOrder            │
│    • Queries: currentUser, myOrders, transactionStatus     │
│                                                            │
│  Services:                                                 │
│    • SolanaAuthService (JWT token generation)              │
│    • SolanaTransactionService (Blockchain verification)    │
│    • SolanaTransactionBuilderService (Send transactions)   │
│                                                            │
│  Background Jobs:                                          │
│    • PaymentMonitorJob (Monitor incoming payments)        │
│    • VendorFulfillmentJob (Deliver game credits)          │
│                                                            │
│  Controllers:                                              │
│    • GraphqlController (GraphQL endpoint)                  │
└────────────────────┬───────────────────────────────────────┘
                     │
                     │ ActiveRecord
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│                   POSTGRESQL DATABASE                      │
├────────────────────────────────────────────────────────────┤
│  Core Tables:                                              │
│    • users (wallet_address, email)                         │
│    • orders (order_number, amount, status, user_data)      │
│    • crypto_transactions (transaction_signature, state)    │
│    • topup_products, topup_product_items                   │
│    • fiat_currencies (USDT, USDC, USD)                     │
│                                                            │
│  Supporting Tables:                                        │
│    • game_accounts                                         │
│    • audit_logs                                            │
│    • vendor_transaction_logs                               │
│    • verification_cache                                    │
└────────────────────┬───────────────────────────────────────┘
                     │
                     │
        ┌────────────┴────────────┬────────────────┐
        │                         │                │
        ▼                         ▼                ▼
┌───────────────┐    ┌────────────────────┐   ┌──────────────┐
│  BLOCKCHAIN   │    │   VENDOR APIs      │   │ ADMIN PANEL  │
│   (Solana)    │    │   (Moogold, etc.)  │   │   (Manual)   │
├───────────────┤    ├────────────────────┤   ├──────────────┤
│ • RPC Node    │    │ • Order Fulfillment│   │ • Refunds    │
│ • Verify TX   │    │ • Game Credit      │   │ • Manual Ops │
│ • Get Balance │    │   Delivery         │   │ • Monitoring │
│ • Transaction │    │ • Status Updates   │   │              │
│   Status      │    │                    │   │              │
└───────────────┘    └────────────────────┘   └──────────────┘

FLOW:
1. User → Wallet App: Connect wallet and authenticate (authenticateWallet)
2. User → Frontend: Browse products and select item
3. User → Frontend: Click "Buy Now" to initiate order
4. User → Wallet App: Approve payment transaction
5. Frontend → Backend API: Send transaction signature via createOrder mutation
6. Backend → Blockchain RPC: Verify transaction on-chain
7. Backend → Database: Create order & crypto_transaction records
8. Backend → Vendor API: Fulfill order (deliver game credits)
9. Backend → Database: Update order status to 'succeeded'

```

---

## 6. Test Scenarios

### Test Case 1: Successful Purchase

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TEST: Successful Game Credit Purchase                                       │
└─────────────────────────────────────────────────────────────────────────────┘

GIVEN:
  - User authenticated with wallet address via authenticateWallet
  - TopupProduct "ML Diamonds" is active
  - TopupProductItem "500 Diamonds" costs 0.05 SOL

WHEN:
  1. User authenticates wallet (authenticateWallet mutation)
  2. User browses products and selects "500 Diamonds"
  3. User clicks "Buy Now" to initiate purchase
  4. User approves payment in wallet app (0.05 SOL to platform wallet)
  5. Wallet app returns transaction signature
  6. Frontend calls createOrder mutation with signature
  7. Backend verifies transaction on blockchain
  8. Backend creates Order & CryptoTransaction records
  9. Order.pay! is called (pending → paid)
  10. Vendor API successfully delivers credits
  11. Order.success! is called (paid → succeeded)

THEN:
  ✓ Order status: pending → paid → succeeded
  ✓ CryptoTransaction state: confirmed
  ✓ User receives 500 diamonds in game account
  ✓ AuditLog records all actions

DATABASE STATE:
  - users: 1 record (wallet_address: "9fZ8X...")
  - orders: 1 record (status: succeeded)
  - crypto_transactions: 1 record (state: confirmed)
  - audit_logs: Multiple records (wallet_connection, order_created, etc.)
```

### Test Case 2: Failed Purchase (Manual Refund Required)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TEST: Failed Purchase Requiring Manual Refund                               │
└─────────────────────────────────────────────────────────────────────────────┘

GIVEN:
  - User has order in 'paid' status
  - Payment verified on blockchain (0.05 SOL)
  - Vendor API returns error (game account invalid)

WHEN:
  - Order.fail! is called

THEN:
  ✓ Order status: paid → failed
  ✓ Admin notified for manual refund
  ✓ User notified of failure
  ✗ Automatic refund NOT processed (crypto requires manual handling)

DATABASE STATE:
  - orders: 1 record (status: failed)
  - crypto_transactions: 1 record (state: confirmed)
  - Admin dashboard shows pending refund request

ADMIN ACTION REQUIRED:
  - Review failed order
  - Initiate Solana transfer back to user's wallet
  - Update order notes with refund transaction signature
```

### Test Case 3: Invalid Transaction Signature

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TEST: Invalid Transaction Signature                                         │
└─────────────────────────────────────────────────────────────────────────────┘

GIVEN:
  - User submits invalid transaction signature
  - Order in 'pending' status

WHEN:
  - Background job verifies transaction
  - Solana RPC returns transaction not found

THEN:
  ✗ CryptoTransaction state: pending → failed
  ✗ Order status: pending → failed
  ✓ No payment received
  ✓ User shown error message

DATABASE STATE:
  - orders: 1 record (status: failed)
  - crypto_transactions: 1 record (state: failed)
  - No refund needed (payment never received)
```

### Test Case 4: Concurrent Order Attempts

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TEST: Concurrent Order Creation                                             │
└─────────────────────────────────────────────────────────────────────────────┘

GIVEN:
  - User attempts two simultaneous orders
  - Each order for different products

WHEN:
  - Both requests hit server concurrently
  - Each creates separate Order and CryptoTransaction

THEN:
  ✓ Both orders created successfully (no wallet balance to check)
  ✓ Each order has unique order_number
  ✓ Each crypto_transaction has unique transaction_signature
  ✓ Payment verification happens independently for each

DATABASE STATE:
  - orders: 2 records (both pending initially)
  - crypto_transactions: 2 records (both pending initially)
  - Each processes based on actual blockchain payment
```

---

## 7. Key Relationships Summary

```
USER
├─► has_many Orders
│   ├─► belongs_to TopupProductItem
│   ├─► has_one CryptoTransaction
│   └─► has_many VendorTransactionLogs
└─► has_many GameAccounts

ORDER
├─► belongs_to User
├─► has_one CryptoTransaction
├─► has_many VendorTransactionLogs
└─► AASM-controlled status

CRYPTO_TRANSACTION
└─► belongs_to Order

AUDIT_LOG
└─► polymorphic auditable

VERIFICATION_CACHE
└─► standalone by transaction_signature

```

---

## 8. Database Indexes & Performance

```
HIGH PRIORITY INDEXES:
✓ users(wallet_address) - UNIQUE
✓ orders(order_number) - UNIQUE
✓ crypto_transactions(transaction_signature) - UNIQUE
✓ crypto_transactions(order_id) - UNIQUE

QUERY OPTIMIZATION:
✓ orders(user_id, status, created_at)
✓ orders(user_id, fiat_currency_id)
✓ orders(status, fiat_currency_id)
✓ crypto_transactions(state, created_at)
✓ vendor_transaction_logs(order_id, status)
✓ game_accounts(user_id, game_id)
✓ audit_logs(auditable_type, auditable_id)
✓ fiat_currencies(code) - UNIQUE
✓ fiat_currencies(is_active)
✓ fiat_currencies(is_default)

CONCURRENCY & LOCKS:
- Order.with_lock during payment verification
- Unique signature constraint prevents double spends

```

---

This updated diagram reflects the crypto-only architecture without automatic refund capabilities!