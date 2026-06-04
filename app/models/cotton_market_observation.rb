class CottonMarketObservation < ApplicationRecord
  include AttachableRecord

  CATEGORIES = {
    "mandi_wise" => "Raw Cotton Rate - Mandi Wise",
    "gin_wise" => "Raw Cotton Rate - Gin Wise",
    "cci_mandi" => "CCI Mandi Rates",
    "tdn_moisture" => "TDN Rates With Moisture",
    "comparison_sheet" => "Comparison Sheet"
  }.freeze

  TEMPLATE_ROW_PRESETS = {
    "mandi_wise" => [
      { name: "Kukshi", position: 1, remarks: "Krishi Upaj Mandi - Kukshi" },
      { name: "Anjad", position: 2, remarks: "Krishi Upaj Mandi - Anjad" },
      { name: "Dhamnod", position: 3, remarks: "Krishi Upaj Mandi - Dhamnod" },
      { name: "Sausar", position: 4, remarks: "Krishi Upaj Mandi - Sausar" },
      { name: "Ratlam - DCH", position: 5, remarks: "Krishi Upaj Mandi - Ratlam" },
      { name: "Petlawad (Bamnia) - DCH", position: 6, remarks: "Krishi Upaj Mandi - Petlawad" }
    ].freeze,
    "cci_mandi" => [
      { name: "Anjad CCI", position: 1, remarks: "Krishi Upaj Mandi - Anjad CCI" },
      { name: "Kukshi CCI", position: 2, remarks: "Krishi Upaj Mandi - Kukshi CCI" }
    ].freeze
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

  def self.template_grid_supported?(category)
    TEMPLATE_ROW_PRESETS.key?(category.to_s)
  end

  def self.template_rows_for(category)
    TEMPLATE_ROW_PRESETS.fetch(category.to_s, []).map(&:dup)
  end
end
