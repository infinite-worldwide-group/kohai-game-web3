# frozen_string_literal: true

module Queries
  module Topups
    class TopupProducts < Queries::BaseQuery
      description "Get all topup products with filtering"

      type [Types::TopupProductType], null: false

      argument :category_id, ID, required: false
      argument :page, Integer, required: false, default_value: 1
      argument :per_page, Integer, required: false, default_value: 20
      argument :search, String, required: false
      argument :country_code, String, required: false
      argument :for_store, Boolean, required: false
      argument :genre, String, required: false

      def resolve(category_id: nil, page: 1, per_page: 20, search: nil, country_code: nil, for_store: nil, genre: nil)
        products = ::TopupProduct.active

        # Filter by category
        products = products.by_category(category_id) if category_id.present?

        # Filter by search
        if search.present?
          products = products.where("title ILIKE ? OR description ILIKE ?", "%#{search}%", "%#{search}%")
        end

        # Filter by genre (using category for now)
        products = products.by_category(genre) if genre.present?

        # Eager load topup_product_items to prevent N+1 queries
        # This loads all items in a single query instead of one query per product
        products = products.includes(:topup_product_items)

        # Pagination
        products = products.recent.offset((page - 1) * per_page).limit(per_page)

        products
      end
    end
  end
end
