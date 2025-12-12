class AddReferralFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :referred_by_id, :bigint
    add_column :users, :referral_applied_at, :datetime

    add_foreign_key :users, :users, column: :referred_by_id
    add_index :users, :referred_by_id
  end
end
