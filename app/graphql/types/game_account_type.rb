# frozen_string_literal: true

module Types
  class GameAccountType < Types::BaseObject
    description "A game account linked to a user"

    field :id, ID, null: false
    field :user_id, Integer, null: false
    field :topup_product_id, Integer, null: true
    field :game_id, Integer, null: true
    field :account_id, String, null: true
    field :server_id, String, null: true
    field :in_game_name, String, null: true
    field :approve, Boolean, null: false
    field :status, String, null: false
    field :user_data, GraphQL::Types::JSON, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :topup_product, Types::TopupProductType, null: true
    field :display_name, String, null: false

    def display_name
      object.display_name
    end
  end
end
