# frozen_string_literal: true

module Types
  class BaseMutation < GraphQL::Schema::Mutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    object_class Types::BaseObject

    # Helper method to get current user from context
    def current_user
      context[:current_user]
    end

    # Helper method to require authentication
    def require_authentication!
      raise GraphQL::ExecutionError, "Authentication required" unless current_user
    end

    # Helper method to return single error response
    def respond_single_error(message)
      {
        message: message,
        order_number: nil,
        errors: [message]
      }
    end

    # Helper method to return success response
    def respond_success(message:, order_number: nil)
      {
        message: message,
        order_number: order_number,
        errors: []
      }
    end
  end
end
