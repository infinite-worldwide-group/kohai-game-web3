
dependencies
bundle add graphql
rails generate graphql:install

app/graphql/
├── mutations/
│   ├── users/
│   │   └── connect_wallet.rb
│   ├── orders/
│   │   ├── create_order.rb
│   │   └── verify_transaction.rb
│   └── game_accounts/
│       └── add_game_account.rb
├── types/
│   ├── user_type.rb
│   ├── order_type.rb
│   ├── crypto_transaction_type.rb
│   ├── topup_product_type.rb
│   ├── topup_product_item_type.rb
│   └── game_account_type.rb
└── kohai_schema.rb

