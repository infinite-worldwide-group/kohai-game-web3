# frozen_string_literal: true

module Queries
  module Users
    class CurrentUser < Queries::BaseQuery
      description "Get the currently authenticated user"

      type Types::UserType, null: true

      def resolve
        current_user
      end
    end
  end
end
