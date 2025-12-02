# frozen_string_literal: true

module Mutations
  module User
    module GameAccounts
      class ValidateGameAccountMutation < BaseMutation
        description "Validate a game account with the vendor"

        argument :game_account_id, Integer, required: true

        field :game_account, Types::GameAccountType, null: true
        field :success, Boolean, null: false
        field :errors, [String], null: false

        def resolve(game_account_id:)
          current_user = context[:current_user]

          unless current_user
            return {
              game_account: nil,
              success: false,
              errors: ["Authentication required"]
            }
          end

          game_account = current_user.game_accounts.find_by(id: game_account_id)

          unless game_account
            return {
              game_account: nil,
              success: false,
              errors: ["Game account not found"]
            }
          end

          if game_account.validate_with_vendor!
            {
              game_account: game_account.reload,
              success: true,
              errors: []
            }
          else
            {
              game_account: game_account,
              success: false,
              errors: ["Validation failed with vendor"]
            }
          end
        end
      end
    end
  end
end
