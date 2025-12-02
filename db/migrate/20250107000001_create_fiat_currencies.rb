# frozen_string_literal: true

class CreateFiatCurrencies < ActiveRecord::Migration[7.1]
  def change
    create_table :fiat_currencies do |t|
      t.string :code, null: false # USDT, USDC, USD
      t.string :name, null: false # Tether USD, USD Coin
      t.string :symbol, null: false # USDT, USDC
      t.string :token_mint # SPL token mint address for crypto
      t.integer :decimals, default: 6 # 6 for USDT/USDC
      t.string :network # solana, ethereum, etc.
      t.decimal :usd_rate, precision: 18, scale: 8, default: 1.0 # Exchange rate to USD
      t.boolean :is_active, default: true
      t.boolean :is_default, default: false
      t.jsonb :metadata

      t.timestamps
    end

    add_index :fiat_currencies, :code, unique: true
    add_index :fiat_currencies, :token_mint, unique: true, where: "token_mint IS NOT NULL"
    add_index :fiat_currencies, :is_active
  end
end
