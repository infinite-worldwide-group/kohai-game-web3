# Frontend Product Grouping Guide (Option 1)

## How It Works

The backend GraphQL now extracts `game_name` and `region_code` from the product title automatically.

## Backend Response Example

```graphql
query {
  topupProducts {
    id
    title
    gameName        # NEW: "Mobile Legends: Bang Bang"
    regionCode      # NEW: "MY/SG"
    topupProductItems {
      id
      name
      price
    }
  }
}
```

### Sample Response Data

```json
{
  "data": {
    "topupProducts": [
      {
        "id": "145",
        "title": "Mobile Legends: Bang Bang (MY/SG)",
        "gameName": "Mobile Legends: Bang Bang",
        "regionCode": "MY/SG",
        "topupProductItems": [
          { "id": "1", "name": "500 Diamonds", "price": "0.04" }
        ]
      },
      {
        "id": "146",
        "title": "Mobile Legends: Bang Bang (PH/TH)",
        "gameName": "Mobile Legends: Bang Bang",
        "regionCode": "PH/TH",
        "topupProductItems": [
          { "id": "2", "name": "500 Diamonds", "price": "10.00" }
        ]
      },
      {
        "id": "90",
        "title": "Blood Strike",
        "gameName": "Blood Strike",
        "regionCode": "GLOBAL",
        "topupProductItems": [...]
      }
    ]
  }
}
```

## Frontend Implementation (JavaScript/React Example)

```javascript
// Step 1: Group products by game_name
const groupedByGame = products.reduce((acc, product) => {
  const gameName = product.gameName;
  if (!acc[gameName]) {
    acc[gameName] = [];
  }
  acc[gameName].push(product);
  return acc;
}, {});

// Result:
// {
//   "Mobile Legends: Bang Bang": [
//     { id: 145, regionCode: "MY/SG", ... },
//     { id: 146, regionCode: "PH/TH", ... }
//   ],
//   "Blood Strike": [
//     { id: 90, regionCode: "GLOBAL", ... }
//   ]
// }

// Step 2: Render UI
function ProductSelector() {
  const [selectedGame, setSelectedGame] = useState(null);
  const [selectedRegion, setSelectedRegion] = useState(null);
  
  const games = Object.keys(groupedByGame);
  const regions = selectedGame ? groupedByGame[selectedGame] : [];
  
  return (
    <div>
      {/* First dropdown: Select Game */}
      <select onChange={(e) => setSelectedGame(e.target.value)}>
        <option value="">Select Game</option>
        {games.map(game => (
          <option key={game} value={game}>{game}</option>
        ))}
      </select>
      
      {/* Second dropdown: Select Region */}
      {selectedGame && (
        <select onChange={(e) => setSelectedRegion(e.target.value)}>
          <option value="">Select Region</option>
          {regions.map(product => (
            <option key={product.id} value={product.id}>
              {product.regionCode}
            </option>
          ))}
        </select>
      )}
      
      {/* Show items for selected region */}
      {selectedRegion && (
        <div>
          {regions.find(p => p.id === parseInt(selectedRegion))?.topupProductItems.map(item => (
            <div key={item.id}>{item.name} - {item.price}</div>
          ))}
        </div>
      )}
    </div>
  );
}
```

## What Changed on Backend

Only **2 new fields** added to `TopupProductType`:
- `game_name`: Extracts base game name from title
- `region_code`: Extracts region from title (defaults to "GLOBAL")

The parsing logic:
- Removes everything in parentheses and after
- Example: "Mobile Legends: Bang Bang (MY/SG)" → "Mobile Legends: Bang Bang"
- Region extraction: "Mobile Legends: Bang Bang (MY/SG)" → "MY/SG"

## No Database Changes Required ✅

This approach requires **zero database modifications**.
