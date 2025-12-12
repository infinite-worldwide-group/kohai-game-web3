class CreateReferrerEarnings < ActiveRecord::Migration[7.1]
  def change
    create_table :referrer_earnings do |t|
      t.references :referrer, null: false, foreign_key: { to_table: :users }, index: true
      t.references :referred_user, null: false, foreign_key: { to_table: :users }
      t.references :order, null: false, foreign_key: true
      t.references :referral, null: false, foreign_key: true
      t.decimal :order_amount, precision: 18, scale: 8, null: false
      t.decimal :commission_percent, precision: 5, scale: 2, null: false
      t.decimal :commission_amount, precision: 18, scale: 8, null: false
      t.string :currency, null: false, default: 'USDT'
      t.string :status, null: false, default: 'pending'
      t.datetime :claimed_at
      t.string :claim_transaction_signature

      t.timestamps
    end

    add_index :referrer_earnings, [:referrer_id, :status]
    add_index :referrer_earnings, [:referred_user_id, :order_id], unique: true
  end
end
