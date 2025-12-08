# frozen_string_literal: true

module Queries
  module Currencies
    class SupportedCurrencies < Queries::BaseQuery
      type [Types::FiatCurrencyType], null: false
      description "Get all supported currencies with live exchange rates"

      argument :active_only, Boolean, required: false, default_value: true, description: "Only return active currencies"
      argument :network, String, required: false, description: "Filter by network (e.g., 'solana') or null for fiat"

      def resolve(active_only:, network: nil)
        currencies = active_only ? FiatCurrency.active : FiatCurrency.all
        
        currencies = currencies.where(network: network) if network.present?
        
        currencies.order(is_default: :desc, code: :asc)
      end
    end
  end
end
