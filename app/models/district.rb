class District < ApplicationRecord
  belongs_to :state

  has_many :markets, dependent: :restrict_with_error
  has_many :daily_price_arrival_reports, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :code, with: ->(value) { value.to_s.strip.upcase }

  validates :name, presence: true, uniqueness: { scope: :state_id, case_sensitive: false }

  scope :ordered, -> { order(:name) }
end
