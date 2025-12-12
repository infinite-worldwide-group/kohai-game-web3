class ReferralCode < ApplicationRecord
  belongs_to :user
  has_many :referrals, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true, length: { is: 8 }
  validates :user_id, uniqueness: true

  before_validation :generate_code, on: :create

  private

  def generate_code
    return if code.present?

    loop do
      self.code = SecureRandom.alphanumeric(8).upcase
      break unless ReferralCode.exists?(code: code)
    end
  end
end
