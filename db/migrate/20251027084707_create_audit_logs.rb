class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.integer :user_id
      t.string :action
      t.string :auditable_type
      t.integer :auditable_id
      t.jsonb :old_values
      t.jsonb :new_values
      t.string :ip_address
      t.string :user_agent
      t.string :platform
      t.string :referrer
      t.string :request_id
      t.jsonb :metadata

      t.timestamps
    end

    add_index :audit_logs, :user_id
    add_index :audit_logs, :action
    add_index :audit_logs, [:auditable_type, :auditable_id]
    add_index :audit_logs, :created_at
  end
end
