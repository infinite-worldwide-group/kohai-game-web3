# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class UserInputTypeInput < Types::BaseInputObject
        argument :name, String, required: true
        argument :value, String, required: true
      end
    end
  end
end
