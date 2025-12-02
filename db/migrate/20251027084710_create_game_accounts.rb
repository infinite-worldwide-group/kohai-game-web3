class CreateGameAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :game_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :topup_product, foreign_key: true
      t.integer :game_id
      t.string :account_id
      t.string :server_id
      t.string :in_game_name
      t.boolean :approve, default: false
      t.string :status, default: 'active'
      t.jsonb :user_data, default: {}

      t.timestamps
    end

    add_index :game_accounts, :account_id
    add_index :game_accounts, :game_id
    add_index :game_accounts, :approve
    add_index :game_accounts, :status
    add_index :game_accounts, [:user_id, :topup_product_id]
  end
end
