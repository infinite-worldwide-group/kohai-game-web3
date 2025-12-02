# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class ValidateGameAccount < Mutations::BaseMutation
        description 'Validate Game Account'

        field :message, String, null: false
        field :ign, String, null: true

        argument :input, Mutations::User::Topups::ValidateGameAccountInput, required: true

        def resolve(input:)
          topup_product = ::TopupProduct.find(input[:id])

          return respond_single_error('Product not found') unless topup_product.present?

          response = ::VendorService.validate_game_account(
            topup_product: topup_product,
            user_input: input[:user_inputs]
          )

          unless response[:data].present? && response[:data][:ign].present?
            if response[:message] == "Invalid game account"
              return respond_single_error('Account not found in the game, please check your account ID')
            else
              return respond_single_error("Game Credit is not available at the moment due to ongoing maintenance by #{topup_product.publisher.name} Please try again later.")
            end
          end

          {
            message: response[:message],
            ign: response[:data][:ign]
          }
        end
      end
    end
  end
end
