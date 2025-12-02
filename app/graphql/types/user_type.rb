# frozen_string_literal: true

module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :wallet_address, String, null: false
    field :email, String, null: true
    field :email_verified, Boolean, null: false
    field :email_verified_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Don't expose orders in user type to prevent deep queries
    # Use a separate query for user orders if needed

    def email_verified
      object.email_verified?
    end
  end
end
