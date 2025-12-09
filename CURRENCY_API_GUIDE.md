# Currency API Documentation for Frontend

## Overview
The currency system now uses **real-time exchange rates** updated every 4 hours from external APIs. All conversions are accurate and reflect current market rates.

---

## GraphQL Queries

### 1. Get All Supported Currencies

Fetch all available currencies with live exchange rates.

```graphql
query {
  supportedCurrencies(activeOnly: true) {
    code
    name
    symbol
    usdRate
    decimals
    network
    isActive
    isDefault
    displayName
  }
}
```

**Response:**
```json
{
  "data": {
    "supportedCurrencies": [
      {
        "code": "USDT",
        "name": "Tether USD",
        "symbol": "USDT",
        "usdRate": 1.0,
        "decimals": 6,
        "network": "solana",
        "isActive": true,
        "isDefault": true,
        "displayName": "Tether USD (USDT)"
      },
      {
        "code": "MYR",
        "name": "Malaysian Ringgit",
        "symbol": "RM",
        "usdRate": 0.24213075,
        "decimals": 2,
        "network": null,
        "isActive": true,
        "isDefault": false,
        "displayName": "Malaysian Ringgit (RM)"
      }
      // ... more currencies
    ]
  }
}
```

**Arguments:**
- `activeOnly` (Boolean, optional, default: true) - Only return active currencies
- `network` (String, optional) - Filter by network (e.g., "solana") or null for fiat currencies

**Example: Get only Solana tokens**
```graphql
query {
  supportedCurrencies(activeOnly: true, network: "solana") {
    code
    name
    symbol
    tokenMint
  }
}
```

---

### 2. Convert Currency

Convert amount between any two supported currencies using live rates.

```graphql
query {
  convertCurrency(
    amount: 100
    fromCurrency: "MYR"
    toCurrency: "USDT"
  )
}
```

**Response:**
```json
{
  "data": {
    "convertCurrency": 24.213075
  }
}
```

**Arguments:**
- `amount` (Float, required) - Amount to convert
- `fromCurrency` (String, required) - Source currency code (e.g., "MYR", "USD", "USDT")
- `toCurrency` (String, required) - Target currency code (e.g., "USDT", "SGD", "THB")

**Examples:**
```graphql
# Convert 1000 Thai Baht to USDT
query {
  convertCurrency(amount: 1000, fromCurrency: "THB", toCurrency: "USDT")
}

# Convert 50 USD to Malaysian Ringgit
query {
  convertCurrency(amount: 50, fromCurrency: "USD", toCurrency: "MYR")
}

# Convert 25 USDT to Singapore Dollars
query {
  convertCurrency(amount: 25, fromCurrency: "USDT", toCurrency: "SGD")
}
```

---

## Supported Currencies

### Stablecoins (on Solana)
- **USDT** - Tether USD (default)
- **USDC** - USD Coin

### Fiat Currencies
- **USD** - US Dollar
- **MYR** - Malaysian Ringgit (RM)
- **SGD** - Singapore Dollar (S$)
- **THB** - Thai Baht (฿)
- **IDR** - Indonesian Rupiah (Rp)
- **PHP** - Philippine Peso (₱)
- **VND** - Vietnamese Dong (₫)

---

## Rate Update Schedule

Exchange rates are automatically updated **every 4 hours** from external APIs:
- Primary: exchangerate-api.com
- Fallback: frankfurter.app

Rates are cached for 5 minutes to optimize performance.

---

## Frontend Implementation Examples

### React/TypeScript Example

```typescript
import { gql, useQuery } from '@apollo/client';

const GET_CURRENCIES = gql`
  query GetSupportedCurrencies {
    supportedCurrencies {
      code
      name
      symbol
      usdRate
      decimals
      displayName
    }
  }
`;

const CONVERT_CURRENCY = gql`
  query ConvertCurrency($amount: Float!, $from: String!, $to: String!) {
    convertCurrency(amount: $amount, fromCurrency: $from, toCurrency: $to)
  }
`;

// Component to display currencies
function CurrencySelector() {
  const { data, loading, error } = useQuery(GET_CURRENCIES);
  
  if (loading) return <div>Loading currencies...</div>;
  if (error) return <div>Error loading currencies</div>;
  
  return (
    <select>
      {data.supportedCurrencies.map(currency => (
        <option key={currency.code} value={currency.code}>
          {currency.symbol} - {currency.name}
        </option>
      ))}
    </select>
  );
}

// Component to convert currency
function CurrencyConverter() {
  const [amount, setAmount] = useState(100);
  const [from, setFrom] = useState('MYR');
  const [to, setTo] = useState('USDT');
  
  const { data } = useQuery(CONVERT_CURRENCY, {
    variables: { amount, from, to }
  });
  
  return (
    <div>
      <input 
        type="number" 
        value={amount} 
        onChange={(e) => setAmount(parseFloat(e.target.value))} 
      />
      <span>{from}</span>
      <span>=</span>
      <span>{data?.convertCurrency.toFixed(2)} {to}</span>
    </div>
  );
}
```

---

## Understanding Exchange Rates

The `usdRate` field represents **how much USD 1 unit of the currency equals**.

**Examples:**
- MYR: `usdRate: 0.24213075` means 1 MYR = $0.242 USD
- USDT: `usdRate: 1.0` means 1 USDT = $1.00 USD
- SGD: `usdRate: 0.76923077` means 1 SGD = $0.769 USD

**To display price in local currency:**
```javascript
// Price is in USD/USDT, convert to MYR
const priceUSD = 24.21;
const myrRate = 0.24213075; // from supportedCurrencies query

const priceInMYR = priceUSD / myrRate;
// priceInMYR = 100 MYR
```

Or use the `convertCurrency` query directly:
```graphql
query {
  convertCurrency(amount: 24.21, fromCurrency: "USDT", toCurrency: "MYR")
}
```

---

## Error Handling

The API will return GraphQL errors for:
- Unsupported currency codes
- Invalid amounts (negative, NaN)
- Network/API failures (rare, has fallbacks)

**Example error:**
```json
{
  "errors": [
    {
      "message": "Unsupported currency: XXX"
    }
  ]
}
```

---

## Production Checklist

✅ Database seeded with currencies  
✅ Real-time rates fetched from external API  
✅ Scheduled job runs every 4 hours  
✅ GraphQL API exposed for frontend  
✅ Caching implemented (5-minute cache)  
✅ Fallback API configured  
✅ Error handling in place  

---

## Testing

### Manual Rate Update (Backend)
```bash
bundle exec rails runner "UpdateCurrencyRatesJob.perform_now"
```

### View Current Rates (Backend)
```bash
bundle exec rails runner "FiatCurrency.active.each { |c| puts \"#{c.code}: \$#{c.usd_rate}\" }"
```

### GraphQL Playground
Use your GraphQL playground at `/graphql` to test queries.

---

## Questions?

Contact the backend team if you need:
- Additional currencies
- Different update frequency
- Custom conversion logic
- Historical rate data
