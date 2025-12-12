# Seed tier configurations
puts "Seeding tiers..."

Tier.delete_all

# Create default tiers
# Hold 50,000 – 499,999 $KOHAI → 1% discount forever → ELITE VIP badge
# Hold 500,000 – 2,999,999 $KOHAI → 2% discount forever → MASTER VVIP badge
# Hold 3,000,000+ $KOHAI → 3% discount forever → CHAMPION VVIP+ orange name
tiers_data = [
  {
    name: "Elite VIP",
    tier_key: "elite",
    minimum_balance: 50000,
    discount_percent: 1,
    badge_name: "ELITE VIP",
    badge_color: "silver",
    display_order: 1,
    is_active: true,
    description: "Hold 50,000 – 499,999 $KOHAI tokens for 1% discount forever"
  },
  {
    name: "Master VVIP",
    tier_key: "master",
    minimum_balance: 500000,
    discount_percent: 2,
    badge_name: "MASTER VVIP",
    badge_color: "gold",
    display_order: 2,
    is_active: true,
    description: "Hold 500,000 – 2,999,999 $KOHAI tokens for 2% discount forever"
  },
  {
    name: "Champion VVIP+",
    tier_key: "champion",
    minimum_balance: 3000000,
    discount_percent: 3,
    badge_name: "CHAMPION VVIP+",
    badge_color: "orange",
    display_order: 3,
    is_active: true,
    description: "Hold 3,000,000+ $KOHAI tokens for 3% discount forever with orange name"
  }
]

tiers_data.each do |tier_data|
  tier = Tier.create!(tier_data)
  puts "✓ Created tier: #{tier.name} (#{tier.tier_key})"
end

puts "Tiers seeded successfully!"
