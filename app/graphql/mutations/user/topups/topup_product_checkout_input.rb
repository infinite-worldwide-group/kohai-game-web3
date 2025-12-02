# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class TopupProductCheckoutInput < Types::BaseInputObject
        argument :id, ID, required: true
        argument :item_id, String, required: true
        argument :security_code, String, required: true
        argument :voucher_id, ID, required: false
        argument :user_inputs, [UserInputTypeInput], required: true
      end
    end
  end
end
