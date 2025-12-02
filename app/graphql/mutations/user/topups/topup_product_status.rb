# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class TopupProductStatus < Mutations::BaseMutation
        description 'Status topup product'

        field :orders, [Types::OrderType], null: true

        argument :input, Mutations::User::Topups::TopupProductStatusInput, required: true

        def resolve(input:)
          authenticate_user!

          orders = if input[:order_id].present?

                    order = current_user.orders.find_by_id(input[:order_id])

                    return respond_single_error('Order not found') unless order.present?

                    order.game_credit_status
                    Array(order)
                  else

                    orders = current_user.orders.pending.where(channel: ['vocagame', 'gamepoint', 'synn', 'moogold'])

                    orders.each do |order|
                      order.game_credit_status
                    end
                  end

                  {
                    orders: orders
                  }
        end
      end
    end
  end
end
