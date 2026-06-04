class CottonRegionalComparison < ApplicationRecord
  include AttachableRecord

  belongs_to :cotton_bulletin

  normalizes :line_item, :raipur_value, :ojhar_value, :kukshi_value, :pati_value, :sausar_value, :jobat_value, :odisha_value, :extra_value_one, :extra_value_two,
             with: ->(value) { value.to_s.squish.presence }

  validates :line_item, presence: true

  scope :ordered, -> { order(Arel.sql("COALESCE(position, 999999) ASC"), created_at: :asc) }
end
