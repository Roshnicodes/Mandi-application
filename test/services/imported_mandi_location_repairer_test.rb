require "test_helper"

class ImportedMandiLocationRepairerTest < ActiveSupport::TestCase
  test "moves known MP mandis to their district and removes invalid date labels" do
    state = State.create!(name: "MP")
    imported_district = District.create!(state: state, name: "Imported Markets")
    kukshi = Market.create!(district: imported_district, name: "Kukshi APMC")
    invalid_label = Market.create!(district: imported_district, name: "09/09/2026")

    valid_report = create_report(state, imported_district, kukshi, Date.new(2026, 9, 29))
    invalid_report = create_report(state, imported_district, invalid_label, Date.new(2026, 9, 28))

    result = ImportedMandiLocationRepairer.new.repair

    assert_equal 1, result.moved
    assert_equal 1, result.discarded
    assert_empty result.unresolved_market_names
    assert_not DailyPriceArrivalReport.exists?(invalid_report.id)

    valid_report.reload
    assert_equal "Dhar", valid_report.district.name
    assert_equal "Kukshi", valid_report.market.name
    assert_not District.exists?(id: imported_district.id)
  end

  private
    def create_report(state, district, market, arrival_date)
      group = CommodityGroup.find_or_create_by!(name: "Oilseeds")
      commodity = Commodity.find_or_create_by!(commodity_group: group, name: "Soybean")
      variety = Variety.find_or_create_by!(commodity: commodity, name: "Other")
      grade = Grade.find_or_create_by!(commodity: commodity, variety: variety, name: "Non-FAQ")
      price_unit = PriceUnit.find_or_create_by!(name: "Rs./Quintal") { |unit| unit.short_name = "Rs./Quintal" }
      arrival_unit = ArrivalUnit.find_or_create_by!(name: "Qtl") { |unit| unit.short_name = "Qtl" }

      DailyPriceArrivalReport.create!(
        arrival_date: arrival_date,
        state: state,
        district: district,
        market: market,
        commodity_group: group,
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
