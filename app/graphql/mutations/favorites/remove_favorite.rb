# frozen_string_literal: true

module Mutations
  module Favorites
    class RemoveFavorite < Types::BaseMutation
      description "Remove a product from user's favorites"

      argument :product_id, ID, required: true

      field :topup_product, Types::TopupProductType, null: true
      field :errors, [String], null: false

      def resolve(product_id:)
        require_authentication!

        topup_product = TopupProduct.find_by(id: product_id)

        unless topup_product
          return {
            topup_product: nil,
            errors: ["Product not found"]
          }
        end

        favorite = current_user.user_favorites.find_by(topup_product: topup_product)

        if favorite
          favorite.destroy
        end

        {
          topup_product: topup_product,
          errors: []
        }
      end
    end
  end
end
