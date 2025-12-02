# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class TopupProductCheckout < Mutations::BaseMutation
        description 'Checkout product'

        field :topup_product_checkout, Types::TopupProductCheckoutType, null: false

        argument :input, Mutations::User::Topups::TopupProductCheckoutInput, required: true

        def resolve(input:)
          authenticate_user!

          return respond_single_error('No purchase allow in staging') unless Rails.env.production?

          orders = current_user.orders.topup_product.pending

          if orders.exists?
            orders.each do |order|
              order.game_credit_status
            end

            return respond_single_error('Please wait for your pending topup to complete.') if orders.pending.exists?
          end

          return respond_single_error('Please set your security code first') if current_user.security_code.nil?

          return respond_single_error('Your account has detected an unusual purchase order. Please contact our support for assistance.') if current_user.orders.succeeded.where(order_type: ["purchase", "topup_product"], credit_transaction_id: nil).exists?

          # unless current_user.security_code == input[:security_code]
          #   return respond_single_error('Security code not match')
          # end

          topup_product = ::TopupProduct.find(input[:id])
          vendor = topup_product.vendor

          unless ValidateGameCreditBalanceJob.perform_now(vendor)
            return respond_single_error('This product is currently unavailable. Please try again later.')
          end

          # Handle vendor-specific pre-validation (e.g., gamepoint needs validation before order creation)
          validation_result = perform_vendor_validation(vendor, topup_product, input)
          return validation_result if validation_result.is_a?(Hash) && validation_result[:errors]

          # Unified checkout flow for all vendors
          unified_checkout(input, topup_product, validation_result)
        end

        private

        # Perform vendor-specific validation if required
        def perform_vendor_validation(vendor, topup_product, input)
          case vendor.name.downcase
          when 'gamepoint'
            validate_gamepoint_account(topup_product, input)
          else
            {} # No special validation needed
          end
        end

        # Validate gamepoint account before order creation
        def validate_gamepoint_account(topup_product, input)
          user_input_field = input[:user_inputs].each_with_object({}) do |user_input, hash|
            hash[user_input[:name]] = user_input[:value]
          end

          order_validate = GamepointService.order_validate(
            _product_id: topup_product.origin_id,
            _user_input: user_input_field.transform_keys(&:to_sym)
          )

          unless order_validate.code.to_i == 200
            return respond_single_error('Account not found in the game, please check your account ID')
          end

          result_order_validate = JSON.parse(order_validate.body)

          unless result_order_validate['message'] == 'Success'
            return respond_single_error('Bad request. Please try again later.')
          end

          # Return validation data to be used during purchase
          { validation_token: result_order_validate['validation_token'] }
        end

        # Unified checkout flow for all vendors
        def unified_checkout(input, topup_product, validation_data = {})
          result = TopupProductService.checkout(
            user: current_user,
            checkout_input: input,
            validation_data: validation_data
          )

          return respond_single_error(result[:error]) unless result[:success]

          { topup_product_checkout: result[:checkout_data] }
        end
      end
    end
  end
end
