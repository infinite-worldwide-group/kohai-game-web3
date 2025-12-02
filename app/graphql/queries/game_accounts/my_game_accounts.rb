# frozen_string_literal: true

module Queries
  module GameAccounts
    class MyGameAccounts < Queries::BaseQuery
      type [Types::GameAccountType], null: false
      description "Get all game accounts for the current user"

      argument :topup_product_id, Integer, required: false
      argument :approved_only, Boolean, required: false, default_value: false

      def resolve(topup_product_id: nil, approved_only: false)
        current_user = context[:current_user]

        unless current_user
          raise GraphQL::ExecutionError, "Authentication required"
        end

        game_accounts = current_user.game_accounts.recent

        if topup_product_id.present?
          game_accounts = game_accounts.by_product(topup_product_id)
        end

        if approved_only
          game_accounts = game_accounts.approved
        end

        game_accounts
      end
    end
  end
end
