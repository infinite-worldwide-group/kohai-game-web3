class AddOrderingToTopupProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :topup_products, :ordering, :string
  end
end
