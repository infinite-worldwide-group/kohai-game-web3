# frozen_string_literal: true

module Mutations
  module User
    module GameAccounts
      class DeleteGameAccount < BaseMutation
        description "Disable a game account (soft delete)"

        argument :game_account_id, Integer, required: true

        field :success, Boolean, null: false
        field :errors, [String], null: false

        def resolve(game_account_id:)
          current_user = context[:current_user]

          unless current_user
            return {
              success: false,
              errors: ["Authentication required"]
            }
          end

          game_account = current_user.game_accounts.unscoped.find_by(id: game_account_id)

          unless game_account
            return {
              success: false,
              errors: ["Game account not found"]
            }
          end

          if game_account.disable!
            {
              success: true,
              errors: []
            }
          else
            {
              success: false,
              errors: game_account.errors.full_messages
            }
          end
        end
      end
    end
  end
end
