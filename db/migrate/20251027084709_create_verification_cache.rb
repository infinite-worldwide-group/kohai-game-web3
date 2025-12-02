class CreateVerificationCache < ActiveRecord::Migration[7.1]
  def change
    create_table :verification_caches do |t|
      t.string :transaction_signature, null: false
      t.datetime :last_verified_at
      t.string :verification_status
      t.integer :confirmations, default: 0
      t.references :order, null: false, foreign_key: true

      t.timestamps
    end

    add_index :verification_caches, :transaction_signature, unique: true
    add_index :verification_caches, :verification_status
    add_index :verification_caches, :last_verified_at
  end
end
