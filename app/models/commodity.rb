class Commodity < ApplicationRecord
  belongs_to :commodity_group

  has_many :varieties, dependent: :restrict_with_error
  has_many :grades, dependent: :restrict_with_error
  has_many :daily_price_arrival_reports, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.to_s.squish }

  validates :name, presence: true, uniqueness: { scope: :commodity_group_id, case_sensitive: false }

  scope :ordered, -> { order(:name) }

  def label
    organic? ? "#{name} (Organic)" : name
  end
end
