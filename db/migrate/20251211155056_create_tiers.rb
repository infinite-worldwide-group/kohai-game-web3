class CreateTiers < ActiveRecord::Migration[7.1]
  def change
    create_table :tiers do |t|
      t.string :name, null: false
      t.string :tier_key, null: false
      t.decimal :minimum_balance, precision: 18, scale: 2, null: false
      t.decimal :discount_percent, precision: 5, scale: 2, default: 0
      t.string :badge_name
      t.string :badge_color
      t.integer :display_order, default: 0
      t.boolean :is_active, default: true
      t.text :description
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :tiers, :tier_key, unique: true
    add_index :tiers, :display_order
    add_index :tiers, :is_active
    add_index :tiers, :minimum_balance
  end
end
