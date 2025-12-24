# frozen_string_literal: true

class CreateUserFavorites < ActiveRecord::Migration[7.0]
  def change
    create_table :user_favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :topup_product, null: false, foreign_key: true
      t.timestamps
    end

    add_index :user_favorites, [:user_id, :topup_product_id], unique: true, name: 'index_user_favorites_on_user_and_product'
  end
end
