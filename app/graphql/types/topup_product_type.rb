# frozen_string_literal: true

module Types
  class TopupProductType < Types::BaseObject
    description "A game topup product"

    field :id, ID, null: false
    field :title, String, null: false
    field :description, String, null: true
    field :code, String, null: true
    field :slug, String, null: true
    field :origin_id, String, null: true
    field :category, String, null: true
    field :is_active, Boolean, null: false
    field :featured, Boolean, null: false, description: "Whether this product is featured/priority"
    field :is_priority, Boolean, null: false, description: "Alias for featured field"
    field :publisher, String, null: true
    field :logo_url, String, null: true
    field :avatar_url, String, null: true
    field :publisher_logo_url, String, null: true
    field :country_codes, [String], null: false
    field :user_input, GraphQL::Types::JSON, null: true
    field :vendor_id, ID, null: true
    field :ordering, String, null: true
    field :active, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Helper fields for frontend grouping
    field :game_name, String, null: false, description: "Base game name (extracted from title)"
    field :region_code, String, null: false, description: "Region code extracted from title (e.g., MY/SG, PH/TH)"

    # Vendor object (simplified - just returns vendor_id wrapped in object)
    field :vendor, GraphQL::Types::JSON, null: true

    # Favorites
    field :is_favorite, Boolean, null: false, description: "Whether the current user has favorited this product"

    # Associations
    field :topup_product_items, [Types::TopupProductItemType], null: false do
      description "Available items/packages for this product"
    end

    def topup_product_items
      object.topup_product_items.active.ordered_by_price
    end

    def country_codes
      object.country_codes || []
    end

    def active
      object.is_active
    end

    def is_priority
      object.featured
    end    
    
    def vendor
      return nil unless object.vendor_id
      { id: object.vendor_id }
    end

    def is_favorite
      return false unless context[:current_user]
      context[:current_user].favorite?(object)
    end
  end
end
