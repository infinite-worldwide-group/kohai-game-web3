# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class ValidateGameAccountInput < Types::BaseInputObject
        argument :id, ID, required: true
        argument :user_inputs, [UserInputTypeInput], required: true
      end
    end
  end
end
