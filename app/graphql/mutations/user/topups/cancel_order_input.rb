# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class CancelOrderInput < Types::BaseInputObject
        argument :email, String, required: true
        argument :order_number, String, required: true
      end
    end
  end
end