class CreateReferrals < ActiveRecord::Migration[7.1]
  def change
    create_table :referrals do |t|
      t.references :referrer, null: false, foreign_key: { to_table: :users }, index: true
      t.references :referred_user, null: false, foreign_key: { to_table: :users }, index: { unique: true }
      t.references :referral_code, null: false, foreign_key: true
      t.datetime :applied_at, null: false

      t.timestamps
    end

    add_index :referrals, [:referrer_id, :referred_user_id], unique: true
  end
end
