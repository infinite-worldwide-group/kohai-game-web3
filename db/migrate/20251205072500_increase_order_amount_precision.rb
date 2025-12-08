class IncreaseOrderAmountPrecision < ActiveRecord::Migration[7.1]
  def up
    # Change amount column to support more decimal places
    # This is needed for small USDT amounts (e.g., 0.00242131 USDT)
    # Old: precision 15, scale 2 (only 2 decimal places)
    # New: precision 18, scale 8 (8 decimal places, matching crypto_amount)
    change_column :orders, :amount, :decimal, precision: 18, scale: 8
    change_column :orders, :original_amount, :decimal, precision: 18, scale: 8
    change_column :orders, :discount_amount, :decimal, precision: 18, scale: 8
  end

  def down
    # Revert to original precision (WARNING: may lose precision on existing data)
    change_column :orders, :amount, :decimal, precision: 15, scale: 2
    change_column :orders, :original_amount, :decimal, precision: 15, scale: 6
    change_column :orders, :discount_amount, :decimal, precision: 15, scale: 6
  end
end
