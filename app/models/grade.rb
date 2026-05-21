class Grade < ApplicationRecord
  belongs_to :commodity
  belongs_to :variety, optional: true

  has_many :daily_price_arrival_reports, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.to_s.squish }

  validates :name, presence: true, uniqueness: { scope: [ :commodity_id, :variety_id ], case_sensitive: false }

  scope :ordered, -> { order(:name) }
end
