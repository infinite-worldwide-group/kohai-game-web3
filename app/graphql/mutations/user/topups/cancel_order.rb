# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class CancelOrder < Mutations::BaseMutation
        description 'Cancel Pending Order'

        field :success, Boolean, null: false

        argument :input, Mutations::User::Topups::CancelOrderInput, required: true

        def resolve(input:)
          order = ::Order.pending.find_by(order_number: input[:order_number], email: input[:email])
          return respond_single_error('Cannot find order') unless order.present?

          if order.cancel!
            {
              success: true
            }
          else
            respond_with_errors(order)
          end
        end
      end
    end
  end
end
