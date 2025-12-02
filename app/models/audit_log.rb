class AuditLog < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  # Validations
  validates :action, presence: true

  # Scopes
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_auditable, ->(type, id) { where(auditable_type: type, auditable_id: id) }
  scope :recent, -> { order(created_at: :desc) }

  # Class methods
  def self.log_action(user:, action:, auditable: nil, old_values: {}, new_values: {}, metadata: {})
    create(
      user: user,
      action: action,
      auditable: auditable,
      old_values: old_values,
      new_values: new_values,
      metadata: metadata
    )
  end
end
