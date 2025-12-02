class CreateVendorTransactionLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :vendor_transaction_logs do |t|
      t.integer :order_id, null: false
      t.string :vendor_name, null: false
      t.text :request_body
      t.text :response_body
      t.string :status
      t.integer :retry_count, default: 0
      t.datetime :executed_at

      t.timestamps
    end

    add_index :vendor_transaction_logs, :order_id
    add_index :vendor_transaction_logs, :status
    add_index :vendor_transaction_logs, :vendor_name
    add_index :vendor_transaction_logs, :executed_at
  end
end
