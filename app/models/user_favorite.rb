# frozen_string_literal: true

class UserFavorite < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :topup_product

  # Validations
  validates :user_id, uniqueness: { scope: :topup_product_id, message: "has already favorited this product" }
end
