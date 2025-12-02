# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class TopupProductInquiry < Mutations::BaseMutation
        description 'Inquiry product'

        field :message, String, null: false
        field :ign, String, null: true

        argument :input, Mutations::User::Topups::TopupProductInquiryInput, required: true

        def resolve(input:)
          authenticate_user!

          topup_product = ::TopupProduct.find(input[:id])

          return respond_single_error('Product not found') unless topup_product.present?

          if topup_product.title.include?('MY') && topup_product.code.include?('Mobile Legends')
            product_id = 'mlbb_special'
            is_general = false
          elsif topup_product.title.include?('ID') && topup_product.code.include?('Mobile Legends')
            product_id = 'mlbb_global'
            is_general = false
          elsif topup_product.code.include?('Honor of Kings')
            product_id = 'hok'
            is_general = false
          elsif topup_product.code.include?('Magic Chess')
            product_id = 'magic_chest_gogo'
            is_general = false
          elsif topup_product.vendor.name == 'bro'
            product_id = topup_product.origin_id
            is_general = false
          else
              product_id = topup_product.origin_id
            if topup_product.vendor.name == 'gamepoint'
              is_general = true
            else
              is_general = 'no_validate'
            end
          end
          
          if is_general == 'no_validate'
            response = { 
              "message" => "",
              "data" => { "ign" => input[:game_account_id] }
            }
          else
            response = topup_product.validate_ingame_account({
              product_id: product_id,
              zone_id: input[:zone_id],
              game_account_id: input[:game_account_id].gsub(/\s*\((.*?)\)/, '\1'),
              is_general: is_general
            })
          end

          unless response['data'].present?
            return respond_single_error('Account not found in the game, please check your account ID')
          end

          unless response['data']['ign'].present?
            return respond_single_error('Account not found in the game, please check your account ID')
          end

          {
            message: response['message'],
            ign: response['data']['ign']
          }
        end
      end
    end
  end
end
