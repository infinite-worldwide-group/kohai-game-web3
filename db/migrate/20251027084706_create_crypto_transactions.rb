class CreateCryptoTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :crypto_transactions do |t|
      t.integer :order_id
      t.string :transaction_signature, null: false
      t.string :wallet_from
      t.string :wallet_to
      t.decimal :amount, precision: 18, scale: 8
      t.string :token, null: false
      t.string :network, null: false
      t.integer :decimals
      t.string :transaction_type, null: false
      t.string :direction, null: false
      t.string :state, default: 'pending', null: false
      t.integer :confirmations, default: 0
      t.bigint :block_number
      t.datetime :block_timestamp
      t.decimal :gas_fee, precision: 18, scale: 8
      t.text :metadata
      t.datetime :verified_at

      t.timestamps
    end

    add_index :crypto_transactions, :transaction_signature, unique: true
    add_index :crypto_transactions, :order_id, unique: true
    add_index :crypto_transactions, :wallet_from
    add_index :crypto_transactions, :wallet_to
    add_index :crypto_transactions, :state
    add_index :crypto_transactions, :network
    add_index :crypto_transactions, [:state, :created_at]
  end
end
