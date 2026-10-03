require "test_helper"

class DailyPriceArrivalCommodityNormalizerTest < ActiveSupport::TestCase
  test "merges the Soyabean spelling into Soybean without duplicate report rows" do
    state = State.create!(name: "MP")
    district = District.create!(state: state, name: "Agar Malwa")
    market = Market.create!(district: district, name: "Agar")
    group = CommodityGroup.create!(name: "Oilseeds")
    soybean = Commodity.create!(commodity_group: group, name: "Soybean")
    soyabean = Commodity.create!(commodity_group: group, name: "Soyabean")
    target_variety = Variety.create!(commodity: soybean, name: "Soyabeen")
    source_variety = Variety.create!(commodity: soyabean, name: "Soyabeen")
    target_grade = Grade.create!(commodity: soybean, variety: target_variety, name: "Non-FAQ")
    source_grade = Grade.create!(commodity: soyabean, variety: source_variety, name: "Non-FAQ")

    create_report(state, district, market, soybean, target_variety, target_grade, Date.new(2026, 9, 9))
    duplicate = create_report(state, district, market, soyabean, source_variety, source_grade, Date.new(2026, 9, 9))
    moved = create_report(state, district, market, soyabean, source_variety, source_grade, Date.new(2026, 9, 10))

    result = DailyPriceArrivalCommodityNormalizer.new.normalize

    assert_equal 1, result.moved
    assert_equal 1, result.deduplicated
    assert_equal 1, result.merged_commodities
    assert_not DailyPriceArrivalReport.exists?(duplicate.id)
    assert_equal soybean, moved.reload.commodity
    assert_equal 2, DailyPriceArrivalReport.where(commodity: soybean).count
    assert_not Commodity.exists?(id: soyabean.id)
  end

  private
    def create_report(state, district, market, commodity, variety, grade, arrival_date)
      price_unit = PriceUnit.find_or_create_by!(name: "Rs./Quintal") { |unit| unit.short_name = "Rs./Quintal" }
      arrival_unit = ArrivalUnit.find_or_create_by!(name: "Qtl") { |unit| unit.short_name = "Qtl" }

      DailyPriceArrivalReport.create!(
        arrival_date: arrival_date,
        state: state,
        district: district,
        market: market,
        commodity_group: commodity.commodity_group,
        commodity: commodity,
        variety: variety,
        grade: grade,
        price_unit: price_unit,
        arrival_unit: arrival_unit,
        min_price: 1800,
        max_price: 2200,
        modal_price: 2000,
        arrival_quantity: 50
      )
    end
end
