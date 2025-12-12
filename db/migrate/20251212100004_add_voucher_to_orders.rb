class AddVoucherToOrders < ActiveRecord::Migration[7.1]
  def change
    add_reference :orders, :voucher, foreign_key: true, index: true
    add_column :orders, :voucher_discount_percent, :decimal, precision: 5, scale: 2
    add_column :orders, :voucher_discount_amount, :decimal, precision: 18, scale: 8
    add_column :orders, :final_discount_source, :string
  end
end
