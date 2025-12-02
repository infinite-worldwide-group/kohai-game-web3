# frozen_string_literal: true

module Queries
  module Topups
    class TopupProduct < Queries::BaseQuery
      description "Get a single topup product by ID or slug"

      type Types::TopupProductType, null: true

      argument :id, ID, required: false
      argument :slug, String, required: false

      def resolve(id: nil, slug: nil)
        if id.present?
          ::TopupProduct.find_by(id: id)
        elsif slug.present?
          ::TopupProduct.find_by(slug: slug)
        else
          raise GraphQL::ExecutionError, "Either id or slug must be provided"
        end
      end
    end
  end
end
