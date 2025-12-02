# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class TopupProductInquiryInput < Types::BaseInputObject
        argument :id, ID, required: true
        argument :zone_id, String, required: false
        argument :game_account_id, String, required: true
      end
    end
  end
end
