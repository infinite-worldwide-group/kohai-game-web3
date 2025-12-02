# frozen_string_literal: true

module Queries
  module Orders
    class Order < Queries::BaseQuery
      description "Get an order by ID"

      type Types::OrderType, null: true

      argument :id, ID, required: true

      def resolve(id:)
        ::Order.find(id)
      end
    end
  end
end
