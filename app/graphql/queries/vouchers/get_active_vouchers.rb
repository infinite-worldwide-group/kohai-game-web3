# frozen_string_literal: true

module Queries
  module Vouchers
    class GetActiveVouchers < Queries::BaseQuery
      type [Types::VoucherType], null: false

      def resolve
        require_authentication!
        context[:current_user].active_vouchers
      end
    end
  end
end
