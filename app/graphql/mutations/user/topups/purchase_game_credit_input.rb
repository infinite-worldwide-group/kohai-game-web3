# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class PurchaseGameCreditInput < Types::BaseInputObject
        argument :user_inputs, [UserInputTypeInput], required: true
        argument :item_id, String, required: true
        argument :email, String, required: true
        argument :name, String, required: true
        argument :store_id, ID, required: true
        argument :redirect_url, String, required: true
        argument :gateway, Types::GatewayType, required: true
        argument :product_id, String, required: true
        argument :channel, String, required: false
        argument :signature, String, required: true
      end
    end
  end
end
