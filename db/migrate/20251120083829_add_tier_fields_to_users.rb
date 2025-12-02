class AddTierFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :tier, :string
    add_column :users, :kohai_balance, :decimal, precision: 18, scale: 6
    add_column :users, :tier_checked_at, :datetime

    add_index :users, :tier
  end
end
