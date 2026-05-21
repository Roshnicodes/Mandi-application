class CottonMarketObservation < ApplicationRecord
  CATEGORIES = {
    "mandi_wise" => "Raw Cotton Rate - Mandi Wise",
    "gin_wise" => "Raw Cotton Rate - Gin Wise",
    "cci_mandi" => "CCI Mandi Rates",
    "tdn_moisture" => "TDN Rates With Moisture",
    "comparison_sheet" => "Comparison Sheet"
  }.freeze

  belongs_to :cotton_bulletin

  normalizes :category, with: ->(value) { value.to_s }
  normalizes :name, :moisture, :arrival_price, :remarks, with: ->(value) { value.to_s.squish.presence }

  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }
  validates :name, presence: true, unless: :comparison_sheet?
  validates :arrival_quantity, :minimum_price, :maximum_price, :modal_price, :total_arrival, :traders_buy, :cci_buy, :buy_percentage, :traders_percentage, :cci_percentage,
            numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  scope :ordered, -> { order(Arel.sql("COALESCE(position, 999999) ASC"), created_at: :asc) }

  def category_label
    CATEGORIES[category]
  end

  def comparison_sheet?
    category == "comparison_sheet"
  end

  def effective_cci_percentage
    cci_percentage.presence || buy_percentage
  end
end
