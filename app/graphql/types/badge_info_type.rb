module Types
  class BadgeInfoType < Types::BaseObject
    field :name, String, null: true
    field :color, String, null: true
  end
end
