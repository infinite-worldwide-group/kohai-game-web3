# frozen_string_literal: true

module Queries
  module GameAccounts
    class MyGameAccounts < Queries::BaseQuery
      type [Types::GameAccountType], null: false
      description "Get all game accounts for the current user"

      argument :topup_product_id, Integer, required: false
      argument :approved_only, Boolean, required: false, default_value: false
      argument :recent_purchases_only, Boolean, required: false, default_value: false

      def resolve(topup_product_id: nil, approved_only: false, recent_purchases_only: false)
        current_user = context[:current_user]

        unless current_user
          raise GraphQL::ExecutionError, "Authentication required"
        end

        if recent_purchases_only
          # Show accounts with purchases, ordered by most recent purchase
          game_accounts = current_user.game_accounts.by_recent_purchase
        else
          # Show all accounts, ordered by creation date
          game_accounts = current_user.game_accounts.recent
        end

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
