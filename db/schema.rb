# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_11_20_083829) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.integer "user_id"
    t.string "action"
    t.string "auditable_type"
    t.integer "auditable_id"
    t.jsonb "old_values"
    t.jsonb "new_values"
    t.string "ip_address"
    t.string "user_agent"
    t.string "platform"
    t.string "referrer"
    t.string "request_id"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "crypto_transactions", force: :cascade do |t|
    t.integer "order_id"
    t.string "transaction_signature", null: false
    t.string "wallet_from"
    t.string "wallet_to"
    t.decimal "amount", precision: 18, scale: 8
    t.string "token", null: false
    t.string "network", null: false
    t.integer "decimals"
    t.string "transaction_type", null: false
    t.string "direction", null: false
    t.string "state", default: "pending", null: false
    t.integer "confirmations", default: 0
    t.bigint "block_number"
    t.datetime "block_timestamp"
    t.decimal "gas_fee", precision: 18, scale: 8
    t.text "metadata"
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network"], name: "index_crypto_transactions_on_network"
    t.index ["order_id"], name: "index_crypto_transactions_on_order_id", unique: true
    t.index ["state", "created_at"], name: "index_crypto_transactions_on_state_and_created_at"
    t.index ["state"], name: "index_crypto_transactions_on_state"
    t.index ["transaction_signature"], name: "index_crypto_transactions_on_transaction_signature", unique: true
    t.index ["wallet_from"], name: "index_crypto_transactions_on_wallet_from"
    t.index ["wallet_to"], name: "index_crypto_transactions_on_wallet_to"
  end

  create_table "fiat_currencies", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "symbol", null: false
    t.string "token_mint"
    t.integer "decimals", default: 6
    t.string "network"
    t.decimal "usd_rate", precision: 18, scale: 8, default: "1.0"
    t.boolean "is_active", default: true
    t.boolean "is_default", default: false
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_fiat_currencies_on_code", unique: true
    t.index ["is_active"], name: "index_fiat_currencies_on_is_active"
    t.index ["token_mint"], name: "index_fiat_currencies_on_token_mint", unique: true, where: "(token_mint IS NOT NULL)"
  end

  create_table "game_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "topup_product_id"
    t.integer "game_id"
    t.string "account_id"
    t.string "server_id"
    t.string "in_game_name"
    t.boolean "approve", default: false
    t.string "status", default: "active"
    t.jsonb "user_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_game_accounts_on_account_id"
    t.index ["approve"], name: "index_game_accounts_on_approve"
    t.index ["game_id"], name: "index_game_accounts_on_game_id"
    t.index ["status"], name: "index_game_accounts_on_status"
    t.index ["topup_product_id"], name: "index_game_accounts_on_topup_product_id"
    t.index ["user_id", "topup_product_id"], name: "index_game_accounts_on_user_id_and_topup_product_id"
    t.index ["user_id"], name: "index_game_accounts_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "fiat_currency_id"
    t.integer "topup_product_item_id"
    t.integer "game_account_id"
    t.string "order_number", null: false
    t.decimal "amount", precision: 15, scale: 2
    t.string "currency", default: "SOL"
    t.decimal "original_amount", precision: 15, scale: 6
    t.decimal "discount_amount", precision: 15, scale: 6
    t.decimal "discount_percent", precision: 5, scale: 2
    t.string "tier_at_purchase"
    t.decimal "crypto_amount", precision: 18, scale: 9
    t.string "crypto_currency"
    t.string "status", default: "pending", null: false
    t.string "order_type", default: "topup"
    t.string "payment_method"
    t.string "invoice_id"
    t.text "error_message"
    t.jsonb "user_data"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["fiat_currency_id"], name: "index_orders_on_fiat_currency_id"
    t.index ["game_account_id"], name: "index_orders_on_game_account_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["order_type"], name: "index_orders_on_order_type"
    t.index ["status", "fiat_currency_id"], name: "index_orders_on_status_and_fiat_currency_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["topup_product_item_id"], name: "index_orders_on_topup_product_item_id"
    t.index ["user_id", "fiat_currency_id"], name: "index_orders_on_user_id_and_fiat_currency_id"
    t.index ["user_id", "status", "created_at"], name: "index_orders_on_user_id_and_status_and_created_at"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "topup_product_items", force: :cascade do |t|
    t.bigint "topup_product_id", null: false
    t.string "origin_id"
    t.string "name"
    t.decimal "price", precision: 15, scale: 2
    t.string "currency", default: "MYR", null: false
    t.string "icon"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_topup_product_items_on_active"
    t.index ["origin_id"], name: "index_topup_product_items_on_origin_id"
    t.index ["topup_product_id"], name: "index_topup_product_items_on_topup_product_id"
  end

  create_table "topup_products", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "code"
    t.string "slug"
    t.string "origin_id"
    t.string "category"
    t.boolean "is_active", default: false, null: false
    t.boolean "featured", default: false
    t.string "publisher"
    t.string "logo_url"
    t.string "avatar_url"
    t.string "publisher_logo_url"
    t.jsonb "country_codes", default: []
    t.jsonb "user_input"
    t.integer "vendor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_topup_products_on_category"
    t.index ["code"], name: "index_topup_products_on_code"
    t.index ["featured"], name: "index_topup_products_on_featured"
    t.index ["is_active"], name: "index_topup_products_on_is_active"
    t.index ["origin_id"], name: "index_topup_products_on_origin_id"
    t.index ["slug"], name: "index_topup_products_on_slug", unique: true
    t.index ["vendor_id"], name: "index_topup_products_on_vendor_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "wallet_address", null: false
    t.string "email"
    t.string "auth_code"
    t.datetime "email_verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tier"
    t.decimal "kohai_balance", precision: 18, scale: 6
    t.datetime "tier_checked_at"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["tier"], name: "index_users_on_tier"
    t.index ["wallet_address"], name: "index_users_on_wallet_address", unique: true
  end

  create_table "vendor_transaction_logs", force: :cascade do |t|
    t.integer "order_id", null: false
    t.string "vendor_name", null: false
    t.text "request_body"
    t.text "response_body"
    t.string "status"
    t.integer "retry_count", default: 0
    t.datetime "executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["executed_at"], name: "index_vendor_transaction_logs_on_executed_at"
    t.index ["order_id"], name: "index_vendor_transaction_logs_on_order_id"
    t.index ["status"], name: "index_vendor_transaction_logs_on_status"
    t.index ["vendor_name"], name: "index_vendor_transaction_logs_on_vendor_name"
  end

  create_table "verification_caches", force: :cascade do |t|
    t.string "transaction_signature", null: false
    t.datetime "last_verified_at"
    t.string "verification_status"
    t.integer "confirmations", default: 0
    t.bigint "order_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_verified_at"], name: "index_verification_caches_on_last_verified_at"
    t.index ["order_id"], name: "index_verification_caches_on_order_id"
    t.index ["transaction_signature"], name: "index_verification_caches_on_transaction_signature", unique: true
    t.index ["verification_status"], name: "index_verification_caches_on_verification_status"
  end

  add_foreign_key "game_accounts", "topup_products"
  add_foreign_key "game_accounts", "users"
  add_foreign_key "orders", "fiat_currencies"
  add_foreign_key "orders", "users"
  add_foreign_key "topup_product_items", "topup_products"
  add_foreign_key "verification_caches", "orders"
end
