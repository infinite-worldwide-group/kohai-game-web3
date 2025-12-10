# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    # Add `node(id: ID!) and `nodes(ids: [ID!]!)`
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # User queries
    field :current_user, resolver: Queries::Users::CurrentUser
    field :tier_status, resolver: Queries::Users::TierStatus

    # Order queries
    field :order, resolver: Queries::Orders::Order
    field :my_orders, resolver: Queries::Orders::MyOrders

    # Transaction queries
    field :transaction_status, resolver: Queries::Transactions::TransactionStatus

    # Topup product queries
    field :topup_products, resolver: Queries::Topups::TopupProducts
    field :topup_product, resolver: Queries::Topups::TopupProduct

    # Game account queries
    field :my_game_accounts, resolver: Queries::GameAccounts::MyGameAccounts

    # Currency queries
    field :supported_currencies, resolver: Queries::Currencies::SupportedCurrencies
    field :convert_currency, resolver: Queries::Currencies::ConvertCurrency
  end
end
