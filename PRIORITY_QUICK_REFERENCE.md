# Priority Topup Products - Quick Reference

## ⚡ 30-Second Setup

### Step 1: Mark Product as Priority (Database)
```bash
rails console
TopupProduct.find(1).update(featured: true)
# Exit: exit or Ctrl+D
```

### Step 2: Query with Priority Sorting (GraphQL)
```graphql
{
  topupProducts(sortBy: "priority") {
    id
    title
    featured
    isPriority
  }
}
```

**Result:** Featured products appear first! ✅

---

## 3 Ways to Set Priority

### Way 1️⃣: Database (Permanent)
```ruby
# Mark as priority
TopupProduct.find(1).update(featured: true)

# Mark multiple
TopupProduct.where(id: [1, 2, 3]).update_all(featured: true)

# View featured
TopupProduct.featured.all
```

### Way 2️⃣: GraphQL sortBy (Flexible)
```graphql
# Featured first
{ topupProducts(sortBy: "priority") { title } }

# Recent first
{ topupProducts(sortBy: "recent") { title } }

# Alphabetical
{ topupProducts(sortBy: "title") { title } }
```

### Way 3️⃣: GraphQL featuredOnly (Filter)
```graphql
# Show only priority products
{ topupProducts(featuredOnly: true) { title } }
```

---

## Common Commands

| Task | Command |
|------|---------|
| Mark as priority | `product.update(featured: true)` |
| View priority | `TopupProduct.featured.all` |
| Count priority | `TopupProduct.featured.count` |
| Sort by priority | `sortBy: "priority"` |
| Show only priority | `featuredOnly: true` |
| Unmark priority | `product.update(featured: false)` |

---

## Sort Options

| Sort By | Order |
|---------|-------|
| `priority` | Featured → Recent ⭐ |
| `recent` | Newest → Oldest |
| `title` | A → Z |

---

## Frontend Examples

### React - Show Featured First
```jsx
const { data } = useQuery(gql`
  query { topupProducts(sortBy: "priority") { 
    id title featured isPriority 
  }}
`);

// Featured appears first automatically!
data.topupProducts.map(p => <Card key={p.id} {...p} />)
```

### Vue - Show Featured Badge
```vue
<template>
  <div v-for="product in products" :key="product.id">
    <span v-if="product.isPriority" class="badge">⭐ Featured</span>
    {{ product.title }}
  </div>
</template>
```

---

## Field Names

- `featured` - Boolean (database field)
- `isPriority` - Boolean (GraphQL alias)
- Both return `true` for priority products

---

## One-Line Examples

```bash
# Mark product 1 as priority
rails console -e 'TopupProduct.find(1).update(featured: true); exit'

# View all priority products
rails console -e 'puts TopupProduct.featured.pluck(:title); exit'

# Mark multiple as priority
rails console -e 'TopupProduct.where(category: "games").update_all(featured: true); exit'
```

---

## GraphQL Cheat Sheet

```graphql
# Default (priority sorting)
query { topupProducts { title featured } }

# Featured only
query { topupProducts(featuredOnly: true) { title } }

# With category + priority
query { topupProducts(categoryId: "games", sortBy: "priority") { title } }

# Search + priority
query { topupProducts(search: "Mobile", sortBy: "priority") { title } }

# Recent instead
query { topupProducts(sortBy: "recent") { title createdAt } }
```

---

## Check Current Status

```bash
# In Rails console
rails console
TopupProduct.find(1).featured        # => true/false
TopupProduct.featured.count          # => number of priority products
TopupProduct.featured.pluck(:title)  # => ["Title1", "Title2"]
```

---

## Done! 🎉

Your topup products now support priority/featured display with:
- ✅ Database field (`featured`)
- ✅ GraphQL field (`isPriority`)
- ✅ Sorting options (`sortBy`)
- ✅ Filtering options (`featuredOnly`)

Start using it now!
