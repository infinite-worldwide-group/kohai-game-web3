# frozen_string_literal: true

module Mutations
  module User
    module GameAccounts
      class CreateGameAccount < BaseMutation
        description "Create or update a game account for the current user"

        argument :topup_product_id, Integer, required: false
        argument :account_id, String, required: true
        argument :server_id, String, required: false
        argument :in_game_name, String, required: false
        argument :user_data, GraphQL::Types::JSON, required: false

        field :game_account, Types::GameAccountType, null: true
        field :errors, [String], null: false

        def resolve(topup_product_id: nil, account_id:, server_id: nil, in_game_name: nil, user_data: {})
          current_user = context[:current_user]

          unless current_user
            return {
              game_account: nil,
              errors: ["Authentication required"]
            }
          end

          # Normalize topup_product_id: convert 0 or invalid values to nil
          topup_product_id = nil if topup_product_id.to_i <= 0

          # Validate topup_product exists if provided
          if topup_product_id.present?
            unless TopupProduct.exists?(topup_product_id)
              return {
                game_account: nil,
                errors: ["Topup product not found"]
              }
            end
          end

          # Find or initialize game account
          game_account = GameAccount.unscoped.find_or_initialize_by(
            user_id: current_user.id,
            topup_product_id: topup_product_id,
            account_id: account_id
          )

          game_account.assign_attributes(
            user: current_user,
            server_id: server_id,
            in_game_name: in_game_name,
            user_data: user_data || {},
            approve: false,
            status: 'active'
          )

          if game_account.save
            # Automatically validate with vendor if topup_product_id is present
            if topup_product_id.present?
              game_account.validate_with_vendor!
              game_account.reload
            end

            {
              game_account: game_account,
              errors: []
            }
          else
            # Log validation errors for debugging
            Rails.logger.error "GameAccount save failed: #{game_account.errors.full_messages.join(', ')}"
            Rails.logger.error "GameAccount attributes: #{game_account.attributes.inspect}"

            {
              game_account: nil,
              errors: game_account.errors.full_messages
            }
          end
        rescue => e
          Rails.logger.error "CreateGameAccount exception: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")

          {
            game_account: nil,
            errors: [e.message]
          }
        end
      end
    end
  end
end
