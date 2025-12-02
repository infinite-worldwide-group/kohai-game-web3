class CreateTopupProductItems < ActiveRecord::Migration[7.1]
  def change
    create_table :topup_product_items do |t|
      t.references :topup_product, null: false, foreign_key: true
      t.string :origin_id
      t.string :name
      t.decimal :price, precision: 15, scale: 2
      t.string :currency, default: 'MYR', null: false
      t.string :icon
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :topup_product_items, :origin_id
    add_index :topup_product_items, :active
  end
end
