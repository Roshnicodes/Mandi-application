class CandyRate < ApplicationRecord
  include AttachableRecord

  CATEGORIES = {
    "mch" => "Candy Rate (MCH)",
    "dch" => "Candy Rate (DCH)"
  }.freeze

  belongs_to :cotton_bulletin

  normalizes :category, with: ->(value) { value.to_s }
  normalizes :parameter, :madhya_pradesh_rate, :maharashtra_29mm_rate, :maharashtra_31mm_rate, :odisha_29mm_rate, :odisha_30mm_rate, :reference,
             with: ->(value) { value.to_s.squish.presence }

  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }
  validates :parameter, presence: true

  scope :ordered, -> { order(Arel.sql("COALESCE(position, 999999) ASC"), created_at: :asc) }

  def category_label
    CATEGORIES[category]
  end
end
