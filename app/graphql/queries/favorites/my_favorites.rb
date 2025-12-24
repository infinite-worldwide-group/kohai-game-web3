# frozen_string_literal: true

module Queries
  module Favorites
    class MyFavorites < Queries::BaseQuery
      type [Types::TopupProductType], null: false
      description "Get current user's favorite products"

      def resolve
        require_authentication!
        current_user.favorite_products.where(is_active: true).order(created_at: :desc)
      end
    end
  end
end
