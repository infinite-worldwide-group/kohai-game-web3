# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class TopupProductStatusInput < Types::BaseInputObject
        argument :order_id, ID, required: false
      end
    end
  end
end
