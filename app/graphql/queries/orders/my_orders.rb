# frozen_string_literal: true

module Queries
  module Orders
    class MyOrders < Queries::BaseQuery
      description "Get orders for the current user"

      type [Types::OrderType], null: false

      argument :limit, Integer, required: false, default_value: 20

      def resolve(limit:)
        require_authentication!

        # Eager load associations to prevent N+1 queries
        current_user.orders
          .includes(:user, :crypto_transaction, :topup_product_item)
          .recent
          .limit(limit)
      end
    end
  end
end
