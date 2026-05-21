class CottonSeedRate < ApplicationRecord
  belongs_to :cotton_bulletin

  normalizes :particular, :madhya_pradesh_rate, :odisha_rate, :maharashtra_rate, :reference,
             with: ->(value) { value.to_s.squish.presence }

  validates :particular, presence: true

  scope :ordered, -> { order(Arel.sql("COALESCE(position, 999999) ASC"), created_at: :asc) }
end
