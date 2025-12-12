# Priority Topup Products - Complete Setup Guide

## Overview

You now have **3 ways** to control which topup products show first:

1. **Database: Set `featured` flag** (Permanent)
2. **GraphQL Query: Use `sort_by` parameter** (Flexible sorting)
3. **GraphQL Query: Use `featured_only` filter** (Show only priority)

---

## Method 1: Database - Set Featured Flag

### In Rails Console

```bash
rails console

# Mark a product as priority/featured
product = TopupProduct.find(1)
product.update(featured: true)

# Mark multiple products as featured
TopupProduct.where(title: /MLBB|Mobile Legends/).update_all(featured: true)

# Check featured products
TopupProduct.featured.all
```

### In Database (Direct SQL)

```sql
-- Mark specific product as featured
UPDATE topup_products SET featured = true WHERE id = 1;

-- Mark all products in a category as featured
UPDATE topup_products SET featured = true WHERE category = 'games';

-- Unmark products as featured
UPDATE topup_products SET featured = false WHERE id = 2;

-- Check featured products
SELECT id, title, featured FROM topup_products WHERE featured = true;
```

---

## Method 2: GraphQL - Sort By Priority (Default)

### Query: Show All Products Sorted by Priority

**Products are shown: Featured First → Recent Second**

```graphql
query GetTopupProducts {
  topupProducts(
    sortBy: "priority"
    page: 1
    perPage: 20
  ) {
    id
    title
    featured
    isPriority
    category
    createdAt
  }
}
```

**Response Example:**
```json
{
  "data": {
    "topupProducts": [
      {
        "id": "1",
        "title": "Mobile Legends",
        "featured": true,
        "isPriority": true,
        "category": "games",
        "createdAt": "2025-12-01T10:00:00Z"
      },
      {
        "id": "2",
        "title": "Dota 2",
        "featured": true,
        "isPriority": true,
        "category": "games",
        "createdAt": "2025-12-02T10:00:00Z"
      },
      {
        "id": "5",
        "title": "Honkai Star Rail",
        "featured": false,
        "isPriority": false,
        "category": "games",
        "createdAt": "2025-12-10T10:00:00Z"
      }
    ]
  }
}
```

---

## Method 3: GraphQL - Featured Only

### Query: Show Only Featured/Priority Products

```graphql
query GetFeaturedProducts {
  topupProducts(
    featuredOnly: true
    sortBy: "priority"
  ) {
    id
    title
    featured
    isPriority
    category
  }
}
```

**Response:**
```json
{
  "data": {
    "topupProducts": [
      {
        "id": "1",
        "title": "Mobile Legends",
        "featured": true,
        "isPriority": true,
        "category": "games"
      },
      {
        "id": "2",
        "title": "Dota 2",
        "featured": true,
        "isPriority": true,
        "category": "games"
      }
    ]
  }
}
```

---

## Method 4: GraphQL - Different Sorting Options

### Option A: Sort by Priority (Featured First)

```graphql
query {
  topupProducts(sortBy: "priority") {
    id
    title
    featured
  }
}
```

**Order:** Featured products → Recent products

### Option B: Sort by Recent (Newest First)

```graphql
query {
  topupProducts(sortBy: "recent") {
    id
    title
    createdAt
  }
}
```

**Order:** Newest products first (regardless of featured status)

### Option C: Sort by Title (Alphabetical)

```graphql
query {
  topupProducts(sortBy: "title") {
    id
    title
  }
}
```

**Order:** A → B → C (alphabetically)

### Option D: Default (Priority)

```graphql
query {
  topupProducts {
    # No sortBy = uses "priority" by default
    id
    title
    featured
  }
}
```

---

## Complete Examples

### Example 1: Show Featured Products First in a Category

```graphql
query GetGamesWithPriority {
  topupProducts(
    categoryId: "games"
    sortBy: "priority"
    perPage: 10
  ) {
    id
    title
    featured
    isPriority
    category
    topupProductItems {
      id
      name
      price
      currency
    }
  }
}
```

### Example 2: Show Only Featured Products in a Category

```graphql
query GetFeaturedGames {
  topupProducts(
    categoryId: "games"
    featuredOnly: true
    sortBy: "priority"
  ) {
    id
    title
    featured
    topupProductItems {
      id
      name
      price
    }
  }
}
```

### Example 3: Search with Priority Sorting

```graphql
query SearchProducts {
  topupProducts(
    search: "Mobile Legends"
    sortBy: "priority"
    perPage: 20
  ) {
    id
    title
    featured
    description
  }
}
```

### Example 4: Get Recent Non-Featured Products

```graphql
query {
  topupProducts(
    sortBy: "recent"
    perPage: 5
  ) {
    id
    title
    featured
    createdAt
  }
}
```

---

## Frontend Implementation Examples

### React - Show Featured Products First

```jsx
import { useQuery, gql } from '@apollo/client';

const GET_PRODUCTS_QUERY = gql`
  query GetProducts($featuredOnly: Boolean, $sortBy: String) {
    topupProducts(featuredOnly: $featuredOnly, sortBy: $sortBy) {
      id
      title
      featured
      isPriority
      logoUrl
      topupProductItems {
        id
        name
        price
      }
    }
  }
`;

export function TopupProductsSection() {
  const { data, loading } = useQuery(GET_PRODUCTS_QUERY, {
    variables: {
      featuredOnly: false,
      sortBy: "priority"  // Featured first, then recent
    }
  });

  if (loading) return <div>Loading...</div>;

  return (
    <div className="products-section">
      {data?.topupProducts.map(product => (
        <ProductCard
          key={product.id}
          product={product}
          isFeatured={product.isPriority}
        />
      ))}
    </div>
  );
}

function ProductCard({ product, isFeatured }) {
  return (
    <div className={`product-card ${isFeatured ? 'featured' : ''}`}>
      {isFeatured && (
        <span className="featured-badge">⭐ Featured</span>
      )}
      <h3>{product.title}</h3>
      <img src={product.logoUrl} alt={product.title} />
      
      <div className="items">
        {product.topupProductItems.map(item => (
          <div key={item.id} className="item">
            <span>{item.name}</span>
            <span className="price">${item.price}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
```

### Vue - Show Featured Products

```vue
<template>
  <div class="products-container">
    <!-- Featured Products Section -->
    <section class="featured-section" v-if="featuredProducts.length">
      <h2>Featured Games</h2>
      <div class="products-grid">
        <ProductCard
          v-for="product in featuredProducts"
          :key="product.id"
          :product="product"
          featured
        />
      </div>
    </section>

    <!-- All Products Section -->
    <section class="all-products-section">
      <h2>All Games</h2>
      <div class="products-grid">
        <ProductCard
          v-for="product in allProducts"
          :key="product.id"
          :product="product"
        />
      </div>
    </section>
  </div>
</template>

<script>
import { useQuery, gql } from '@vue/apollo-composable';

const GET_ALL_PRODUCTS = gql`
  query GetAllProducts($sortBy: String) {
    topupProducts(sortBy: $sortBy) {
      id
      title
      featured
      isPriority
      logoUrl
    }
  }
`;

export default {
  setup() {
    const { result, loading } = useQuery(GET_ALL_PRODUCTS, {
      sortBy: "priority"
    });

    return {
      allProducts: () => result.value?.topupProducts || [],
      featuredProducts: () => 
        result.value?.topupProducts?.filter(p => p.featured) || [],
      loading
    };
  }
};
</script>

<style scoped>
.featured-section {
  background: linear-gradient(135deg, #FFD700 0%, #FFA500 100%);
  padding: 2rem;
  margin-bottom: 2rem;
  border-radius: 8px;
}

.featured-section h2 {
  color: #333;
  margin-bottom: 1rem;
}

.products-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
}
</style>
```

---

## Database Management

### View All Featured Products

```bash
rails console

# Get all featured products
TopupProduct.featured.all

# Count featured products
TopupProduct.featured.count

# Get featured products in a category
TopupProduct.active.featured.by_category('games')
```

### Update Featured Status

```bash
rails console

# Mark product as featured
TopupProduct.find(1).update(featured: true)

# Mark multiple as featured
TopupProduct.where(id: [1, 2, 3]).update_all(featured: true)

# Unmark all as featured
TopupProduct.update_all(featured: false)

# Toggle featured status
product = TopupProduct.find(1)
product.update(featured: !product.featured)
```

---

## Admin Panel Usage

### Option 1: Rails Admin (if using rails_admin gem)

```ruby
# config/initializers/rails_admin.rb
RailsAdmin.config do |config|
  config.model 'TopupProduct' do
    list do
      field :title
      field :featured
      field :category
      field :is_active
    end

    edit do
      field :title
      field :featured, :toggle do
        help "Check to mark as priority/featured"
      end
      field :category
      field :is_active
    end
  end
end
```

### Option 2: ActiveAdmin (if using activeadmin gem)

```ruby
# app/admin/topup_products.rb
ActiveAdmin.register TopupProduct do
  permit_params :title, :featured, :category, :is_active

  filter :featured
  filter :category
  filter :is_active

  index do
    selectable_column
    id_column
    column :title
    column :featured do |product|
      status_tag(product.featured ? "Featured" : "Not Featured")
    end
    column :category
    column :is_active
    actions
  end

  form do |f|
    f.inputs do
      f.input :title
      f.input :featured, as: :boolean, label: "Priority/Featured"
      f.input :category
      f.input :is_active
    end
    f.actions
  end
end
```

---

## Display Options in Frontend

### Option 1: Featured Badge

```jsx
function ProductCard({ product }) {
  return (
    <div className="product-card">
      {product.isPriority && (
        <div className="featured-badge">⭐ Featured</div>
      )}
      <img src={product.logoUrl} alt={product.title} />
      <h3>{product.title}</h3>
    </div>
  );
}
```

### Option 2: Featured Section at Top

```jsx
function ProductsList({ products }) {
  const featured = products.filter(p => p.isPriority);
  const others = products.filter(p => !p.isPriority);

  return (
    <div>
      {featured.length > 0 && (
        <section className="featured">
          <h2>Featured Games</h2>
          <Grid>{featured.map(p => <Card key={p.id} {...p} />)}</Grid>
        </section>
      )}
      
      <section className="all">
        <h2>All Games</h2>
        <Grid>{others.map(p => <Card key={p.id} {...p} />)}</Grid>
      </section>
    </div>
  );
}
```

### Option 3: Carousel for Featured

```jsx
function FeaturedCarousel({ products }) {
  const featured = products.filter(p => p.isPriority);
  const [current, setCurrent] = useState(0);

  return (
    <div className="carousel">
      <div className="slide">
        <img src={featured[current].logoUrl} alt="" />
        <h2>{featured[current].title}</h2>
        <button onClick={() => setCurrent((current + 1) % featured.length)}>
          Next
        </button>
      </div>
    </div>
  );
}
```

---

## Summary: 3 Ways to Set Priority

| Method | Where | How | Permanent |
|--------|-------|-----|-----------|
| **1. Database** | Rails console / SQL | `product.update(featured: true)` | Yes ✅ |
| **2. sort_by** | GraphQL query | `sortBy: "priority"` | No (per query) |
| **3. featured_only** | GraphQL query | `featuredOnly: true` | No (per query) |

---

## Quick Start: Mark Products as Priority

### 1. Open Rails Console
```bash
cd /Users/twebcommerce/Projects/kohai-game-web3
rails console
```

### 2. Mark Specific Products as Featured
```ruby
# Mobile Legends as priority
TopupProduct.find_by(title: "Mobile Legends").update(featured: true)

# Mark multiple
TopupProduct.where(code: ["mlbb", "dota2"]).update_all(featured: true)
```

### 3. Verify
```ruby
# Check featured products
TopupProduct.featured.pluck(:title)
# => ["Mobile Legends", "Dota 2"]
```

### 4. Query with GraphQL
```graphql
{
  topupProducts(sortBy: "priority", perPage: 10) {
    id
    title
    featured
    isPriority
  }
}
```

**Result:** Featured products show first! 🎯

---

You can now control the display order in three ways!
