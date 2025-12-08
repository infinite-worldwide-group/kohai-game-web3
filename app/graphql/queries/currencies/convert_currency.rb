# frozen_string_literal: true

module Queries
  module Currencies
    class ConvertCurrency < Queries::BaseQuery
      type Float, null: false
      description "Convert amount between currencies using live exchange rates"

      argument :amount, Float, required: true, description: "Amount to convert"
      argument :from_currency, String, required: true, description: "Source currency code (e.g., MYR)"
      argument :to_currency, String, required: true, description: "Target currency code (e.g., USDT)"

      def resolve(amount:, from_currency:, to_currency:)
        CurrencyConversionService.convert(
          amount,
          from_currency: from_currency,
          to_currency: to_currency
        )
      rescue ArgumentError => e
        raise GraphQL::ExecutionError, e.message
      end
    end
  end
end
