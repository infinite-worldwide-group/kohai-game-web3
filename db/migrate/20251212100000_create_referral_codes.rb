class CreateReferralCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :referral_codes do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :code, null: false
      t.integer :total_uses, default: 0, null: false
      t.decimal :total_earnings, precision: 18, scale: 8, default: 0.0, null: false

      t.timestamps
    end

    add_index :referral_codes, :code, unique: true
  end
end
