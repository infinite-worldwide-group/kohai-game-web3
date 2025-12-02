class CreateTopupProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :topup_products do |t|
      t.string :title, null: false
      t.text :description
      t.string :code
      t.string :slug
      t.string :origin_id
      t.string :category
      t.boolean :is_active, null: false, default: false
      t.boolean :featured, default: false
      t.string :publisher
      t.string :logo_url
      t.string :avatar_url
      t.string :publisher_logo_url
      t.jsonb :country_codes, default: []
      t.jsonb :user_input
      t.integer :vendor_id

      t.timestamps
    end

    add_index :topup_products, :slug, unique: true
    add_index :topup_products, :code
    add_index :topup_products, :origin_id
    add_index :topup_products, :is_active
    add_index :topup_products, :featured
    add_index :topup_products, :vendor_id
    add_index :topup_products, :category
  end
end
