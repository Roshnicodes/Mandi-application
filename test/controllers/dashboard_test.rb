require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    state = State.create!(name: "Madhya Pradesh")
    district = District.create!(state: state, name: "Dhar")
    market = Market.create!(district: district, name: "Kukshi")
    group = CommodityGroup.create!(name: "Cereals")
    commodity = Commodity.create!(commodity_group: group, name: "Maize")
    variety = Variety.create!(commodity: commodity, name: "Other")
    grade = Grade.create!(commodity: commodity, variety: variety, name: "FAQ")
    price_unit = PriceUnit.create!(name: "Rs./Quintal", short_name: "Rs./Quintal")
    arrival_unit = ArrivalUnit.create!(name: "Qtl", short_name: "Qtl")

    [ Date.current - 1.day, Date.current ].each_with_index do |arrival_date, index|
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
        arrival_quantity: 100 + index,
        min_price: 1800,
        max_price: 2200,
        modal_price: 2000
      )
    end
  end

  test "renders the live dashboard insight panels" do
    sign_in_as(@admin)

    get root_path

    assert_response :success
    assert_select ".dashboard-vivid-page"
    assert_select ".dashboard-insights-grid", count: 1
    assert_select ".arrival-chart", count: 1
    assert_select ".commodity-donut", count: 1
    assert_select ".top-mandi-list", count: 1
    assert_select ".top-mandi-row", text: /Kukshi/
  end
end
