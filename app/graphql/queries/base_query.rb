# frozen_string_literal: true

module Queries
  class BaseQuery < GraphQL::Schema::Resolver
    # Helper method to get current user from context
    def current_user
      context[:current_user]
    end

    # Helper method to require authentication
    def require_authentication!
      raise GraphQL::ExecutionError, "Authentication required" unless current_user
    end
  end
end
