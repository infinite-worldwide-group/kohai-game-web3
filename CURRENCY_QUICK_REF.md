# Quick Reference: Currency API

## 🚀 Ready to Use - GraphQL Queries

### Get All Currencies
```graphql
query GetCurrencies {
  supportedCurrencies {
    code
    name
    symbol
    usdRate
    decimals
  }
}
```

### Convert Currency
```graphql
query ConvertPrice($amount: Float!, $from: String!, $to: String!) {
  convertCurrency(amount: $amount, fromCurrency: $from, toCurrency: $to)
}
```

**Example Variables:**
```json
{
  "amount": 100,
  "from": "MYR",
  "to": "USDT"
}
```

## ✅ System Status

- ✓ 9 currencies supported (USDT, USDC, USD, MYR, SGD, THB, IDR, PHP, VND)
- ✓ Real-time rates updated every 4 hours
- ✓ GraphQL API ready
- ✓ Rates are live from external APIs
- ✓ Fallback protection configured

## 📊 Current Live Rates (as of test)

| Currency | Code | Rate (to USD) | Example |
|----------|------|---------------|---------|
| Malaysian Ringgit | MYR | 0.2421 | 100 MYR = 24.21 USDT |
| Singapore Dollar | SGD | 0.7692 | 100 SGD = 76.92 USDT |
| Thai Baht | THB | 0.0312 | 1000 THB = 31.23 USDT |
| Philippine Peso | PHP | 0.0171 | 100 PHP = 1.71 USDT |
| Indonesian Rupiah | IDR | 0.00006 | 100000 IDR = 6.01 USDT |
| Vietnamese Dong | VND | 0.00004 | 100000 VND = 3.81 USDT |

## 🔗 Full Documentation

See `CURRENCY_API_GUIDE.md` for complete API documentation, examples, and best practices.
