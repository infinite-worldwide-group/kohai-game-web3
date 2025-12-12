# frozen_string_literal: true

module Types
  class TopupProductItemType < Types::BaseObject
    description "A topup product item (denomination/package)"

    field :id, ID, null: false
    field :origin_id, String, null: true
    field :name, String, null: true
    field :price, Float, null: true
    field :currency, String, null: false
    field :icon, String, null: true
    field :active, Boolean, null: false
    field :topup_product_id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Helper methods
    field :display_name, String, null: false
    field :formatted_price, String, null: false
    field :price_in_usdt, Float, null: true
    field :discount_percent, Integer, null: false
    field :discount_amount, Float, null: false
    field :discounted_price, Float, null: false
    field :discounted_price_usdt, Float, null: false
    field :tier_info, GraphQL::Types::JSON, null: true

    def display_name
      object.display_name
    end

    def formatted_price
      object.formatted_price
    end

    def price_in_usdt
      return nil unless object.price

      if object.currency == 'MYR'
        CurrencyConversionService.myr_to_usdt(object.price)
      else
        # Assume USD/USDT if not MYR
        object.price
      end
    end

    def currency
      object.currency || 'MYR'
    end

    def discount_percent
      current_user = context[:current_user]
      return 0 unless current_user.present?

      tier_info = TierService.check_tier_status(current_user)
      tier_info[:discount_percent] || 0
    end

    def discount_amount
      price_myr = object.price || 0
      (price_myr * discount_percent / 100.0).round(2)
    end

    def discounted_price
      (object.price || 0) - discount_amount
    end

    def discounted_price_usdt
      discount_percent_val = discount_percent

      if object.currency == 'MYR'
        original_usdt = CurrencyConversionService.myr_to_usdt(object.price)
      else
        original_usdt = object.price || 0
      end

      discount_amount_usdt = (original_usdt * discount_percent_val / 100.0).round(6)
      (original_usdt - discount_amount_usdt).round(6)
    end

    def tier_info
      current_user = context[:current_user]
      return nil unless current_user.present?

      TierService.check_tier_status(current_user)
    end
  end
end
