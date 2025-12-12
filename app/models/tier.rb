class Tier < ApplicationRecord
  require 'ostruct'
  
  # Validations
  validates :name, presence: true
  validates :tier_key, presence: true, uniqueness: true
  validates :minimum_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percent, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :display_order, presence: true, numericality: { only_integer: true }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_order, -> { order(display_order: :asc) }
  scope :by_balance_requirement, -> { order(minimum_balance: :desc) }

  # Class methods
  def self.get_tier_for_balance(balance)
    active.by_balance_requirement.detect { |tier| balance >= tier.minimum_balance } || tier_none
  end

  def self.tier_none
    # Return a nil-like tier for users with no tier
    OpenStruct.new(
      name: "None",
      tier_key: "none",
      minimum_balance: 0,
      discount_percent: 0,
      badge_name: nil,
      badge_color: nil,
      id: nil
    )
  end

  def self.tier_keys
    active.pluck(:tier_key)
  end

  def self.tier_by_key(key)
    active.find_by(tier_key: key)
  end

  # Instance methods
  def display_name
    "#{name} (#{number_with_delimiter(minimum_balance.to_i)} tokens)"
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def badge_info
    {
      name: badge_name,
      color: badge_color
    }
  end

  def tier_benefits
    {
      name: name,
      tier_key: tier_key,
      minimum_balance: minimum_balance,
      discount_percent: discount_percent,
      badge: badge_info,
      description: description
    }
  end
end
