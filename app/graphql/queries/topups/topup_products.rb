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
      argument :featured_only, Boolean, required: false, description: "Show only featured/priority products"
      argument :sort_by, String, required: false, default_value: "priority", description: "Sort by: priority, recent, title, ordering"

      def resolve(category_id: nil, page: 1, per_page: 20, search: nil, country_code: nil, for_store: nil, genre: nil, featured_only: false, sort_by: "priority")
        products = ::TopupProduct.active

        # Filter by featured/priority
        products = products.featured if featured_only

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

        # Sort by priority or other criteria
        case sort_by
        when "priority"
          products = products.by_priority  # Featured first, then recent
        when "recent"
          products = products.recent
        when "title"
          products = products.order(:title)
        when "ordering"
          products = products.by_ordering
        else
          products = products.by_priority  # Default to priority
        end

        # Pagination
        products = products.offset((page - 1) * per_page).limit(per_page)

        products
      end
    end
  end
end
