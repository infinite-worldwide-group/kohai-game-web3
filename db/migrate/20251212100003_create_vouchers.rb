class CreateVouchers < ActiveRecord::Migration[7.1]
  def change
    create_table :vouchers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :referral, foreign_key: true
      t.string :voucher_type, null: false
      t.decimal :discount_percent, precision: 5, scale: 2, null: false
      t.datetime :expires_at, null: false
      t.boolean :used, default: false, null: false
      t.references :order, foreign_key: true
      t.datetime :used_at

      t.timestamps
    end

    add_index :vouchers, [:user_id, :used, :expires_at]
    add_index :vouchers, :voucher_type
  end
end
