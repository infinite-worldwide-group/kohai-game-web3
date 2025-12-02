# frozen_string_literal: true

module Types
  class TopupProductItemType < Types::BaseObject
    description "A topup product item (denomination/package)"

    field :id, ID, null: false
    field :origin_id, String, null: true
    field :name, String, null: true
    field :price, Float, null: true
    field :icon, String, null: true
    field :active, Boolean, null: false
    field :topup_product_id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Helper methods
    field :display_name, String, null: false
    field :formatted_price, String, null: false

    def display_name
      object.display_name
    end

    def formatted_price
      object.formatted_price
    end
  end
end
