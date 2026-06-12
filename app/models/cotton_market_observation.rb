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
  belongs_to :state, optional: true
  belongs_to :district, optional: true
  belongs_to :market, optional: true

  normalizes :category, with: ->(value) { value.to_s }
  normalizes :name, :moisture, :arrival_price, :remarks, with: ->(value) { value.to_s.squish.presence }

  before_validation :align_location_from_market
  before_validation :infer_market_from_name

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

  def market_label
    market&.name || name
  end

  def location_label
    [ state&.name, district&.name ].compact.join(" / ")
  end

  private
    def align_location_from_market
      self.district = market&.district || district
      self.state = district&.state || market&.district&.state || state
    end

    def infer_market_from_name
      return if market.present? || name.blank?
      return unless %w[mandi_wise cci_mandi].include?(category)

      canonical_name = name
        .to_s
        .sub(/\s*-\s*DCH\z/i, "")
        .sub(/\s+CCI\z/i, "")
        .squish

      self.market = Market
        .includes(district: :state)
        .where("LOWER(markets.name) IN (?)", [
          canonical_name.downcase,
          "#{canonical_name} APMC".downcase
        ])
        .first

      align_location_from_market
    end
end
