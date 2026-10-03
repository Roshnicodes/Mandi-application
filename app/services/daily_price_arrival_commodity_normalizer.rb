class DailyPriceArrivalCommodityNormalizer
  COMMODITY_ALIASES = {
    "soyabean" => "soybean"
  }.freeze

  Result = Data.define(:moved, :deduplicated, :merged_commodities)

  def normalize
    @moved = 0
    @deduplicated = 0
    @merged_commodities = 0

    ActiveRecord::Base.transaction do
      COMMODITY_ALIASES.each do |source_name, canonical_name|
        Commodity.where("LOWER(name) = ?", source_name).find_each do |source_commodity|
          target_commodity = source_commodity.commodity_group.commodities
            .where("LOWER(name) = ?", canonical_name)
            .first
          next unless target_commodity.present? && target_commodity != source_commodity

          merge_commodity(source_commodity, target_commodity)
        end
      end
    end

    Result.new(moved: @moved, deduplicated: @deduplicated, merged_commodities: @merged_commodities)
  end

  private
    def merge_commodity(source_commodity, target_commodity)
      source_commodity.daily_price_arrival_reports.find_each do |report|
        target_variety = find_or_create_variety(target_commodity, report.variety.name)
        target_grade = find_or_create_grade(target_commodity, target_variety, report.grade.name)
        existing_report = target_commodity.daily_price_arrival_reports.where(
          arrival_date: report.arrival_date,
          market_id: report.market_id,
          variety_id: target_variety.id,
          grade_id: target_grade.id
        ).first

        if existing_report.present?
          report.destroy!
          @deduplicated += 1
        else
          report.update!(commodity: target_commodity, variety: target_variety, grade: target_grade)
          @moved += 1
        end
      end

      source_commodity.grades.find_each do |grade|
        grade.destroy! if grade.daily_price_arrival_reports.reload.none?
      end
      source_commodity.varieties.find_each do |variety|
        variety.destroy! if variety.grades.reload.none? && variety.daily_price_arrival_reports.reload.none?
      end

      if source_commodity.daily_price_arrival_reports.none? && source_commodity.grades.none? && source_commodity.varieties.none?
        source_commodity.destroy!
        @merged_commodities += 1
      end
    end

    def find_or_create_variety(commodity, name)
      commodity.varieties.where("LOWER(name) = ?", name.downcase).first ||
        Variety.create!(commodity: commodity, name: name)
    end

    def find_or_create_grade(commodity, variety, name)
      commodity.grades.where(variety: variety).where("LOWER(name) = ?", name.downcase).first ||
        Grade.create!(commodity: commodity, variety: variety, name: name)
    end
end
