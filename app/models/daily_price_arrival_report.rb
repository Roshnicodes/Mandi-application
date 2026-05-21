class DailyPriceArrivalReport < ApplicationRecord
  belongs_to :state
  belongs_to :district
  belongs_to :market
  belongs_to :commodity_group
  belongs_to :commodity
  belongs_to :variety
  belongs_to :grade
  belongs_to :price_unit
  belongs_to :arrival_unit

  before_validation :align_hierarchy

  validates :arrival_date, presence: true
  validates :min_price, :max_price, :modal_price, :arrival_quantity,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validate :price_range_is_valid
  validate :modal_price_is_within_range
  validate :location_hierarchy_matches
  validate :commodity_hierarchy_matches

  scope :recent_first, lambda {
    includes(:state, :district, :market, :commodity_group, :commodity, :variety, :grade, :price_unit, :arrival_unit)
      .order(arrival_date: :desc, created_at: :desc)
  }

  def self.filtered(filters)
    reports = recent_first
    reports = reports.where(state_id: filters[:state_id]) if filters[:state_id].present?
    reports = reports.where(district_id: filters[:district_id]) if filters[:district_id].present?
    reports = reports.where(market_id: filters[:market_id]) if filters[:market_id].present?
    reports = reports.where(commodity_group_id: filters[:commodity_group_id]) if filters[:commodity_group_id].present?
    reports = reports.where(commodity_id: filters[:commodity_id]) if filters[:commodity_id].present?
    reports = reports.where(variety_id: filters[:variety_id]) if filters[:variety_id].present?

    if filters[:from_date].present?
      reports = reports.where("arrival_date >= ?", filters[:from_date])
    end

    if filters[:to_date].present?
      reports = reports.where("arrival_date <= ?", filters[:to_date])
    end

    reports
  end

  private
    def align_hierarchy
      self.district = market&.district || district
      self.state = district&.state || market&.district&.state || state
      self.commodity_group = commodity&.commodity_group || commodity_group
    end

    def price_range_is_valid
      return if min_price.blank? || max_price.blank?

      errors.add(:max_price, "must be greater than or equal to minimum price") if max_price < min_price
    end

    def modal_price_is_within_range
      return if min_price.blank? || max_price.blank? || modal_price.blank?
      return if modal_price.between?(min_price, max_price)

      errors.add(:modal_price, "must stay between minimum and maximum price")
    end

    def location_hierarchy_matches
      return if district.blank? || market.blank? || state.blank?

      errors.add(:district, "must belong to the selected state") if district.state_id != state_id
      errors.add(:market, "must belong to the selected district") if market.district_id != district_id
    end

    def commodity_hierarchy_matches
      return if commodity.blank? || variety.blank? || grade.blank? || commodity_group.blank?

      errors.add(:commodity, "must belong to the selected commodity group") if commodity.commodity_group_id != commodity_group_id
      errors.add(:variety, "must belong to the selected commodity") if variety.commodity_id != commodity_id
      errors.add(:grade, "must belong to the selected commodity") if grade.commodity_id != commodity_id
      return if grade.variety_id.blank? || grade.variety_id == variety_id

      errors.add(:grade, "must match the selected variety")
    end
end
