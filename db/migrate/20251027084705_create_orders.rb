class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :fiat_currency, null: true, foreign_key: true
      t.integer :topup_product_item_id
      t.integer :game_account_id
      t.string :order_number, null: false

      # Fiat amounts (for display/accounting)
      t.decimal :amount, precision: 15, scale: 2
      t.string :currency, default: "SOL"

      # Tier/Discount fields
      t.decimal :original_amount, precision: 15, scale: 6
      t.decimal :discount_amount, precision: 15, scale: 6
      t.decimal :discount_percent, precision: 5, scale: 2
      t.string :tier_at_purchase

      # Crypto amounts (actual payment)
      t.decimal :crypto_amount, precision: 18, scale: 9
      t.string :crypto_currency

      t.string :status, null: false, default: "pending"
      t.string :order_type, default: "topup"
      t.string :payment_method
      t.string :invoice_id
      t.text :error_message
      t.jsonb :user_data
      t.jsonb :metadata

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :topup_product_item_id
    add_index :orders, :game_account_id
    add_index :orders, :status
    add_index :orders, :order_type
    add_index :orders, :created_at
    add_index :orders, [:user_id, :status, :created_at]
    add_index :orders, [:user_id, :fiat_currency_id]
    add_index :orders, [:status, :fiat_currency_id]
  end
end
