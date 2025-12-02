class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :wallet_address, null: false
      t.string :email
      t.string :auth_code
      t.datetime :email_verified_at

      t.timestamps
    end

    add_index :users, :wallet_address, unique: true
    add_index :users, :email, unique: true, where: "email IS NOT NULL"
  end
end
