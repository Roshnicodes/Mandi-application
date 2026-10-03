require "test_helper"

class AllPagesSmokeTest < ActionDispatch::IntegrationTest
  test "every page renders with the unified header" do
    sign_in_as(users(:one))

    state = State.create!(name: "Smoke State")
    district = District.create!(state: state, name: "Smoke District")
    market = Market.create!(district: district, name: "Smoke Mandi")
    group = CommodityGroup.create!(name: "Smoke Group")
    commodity = Commodity.create!(commodity_group: group, name: "Smoke Crop")
    variety = Variety.create!(commodity: commodity, name: "Smoke Variety")
    grade = Grade.create!(commodity: commodity, variety: variety, name: "Smoke Grade")
    price_unit = PriceUnit.create!(name: "Smoke Price", short_name: "SP")
    arrival_unit = ArrivalUnit.create!(name: "Smoke Arrival", short_name: "SA")
    bulletin = CottonBulletin.daily_for(Date.new(2030, 6, 1))

    paths = [
      root_path, daily_price_arrival_reports_path, new_daily_price_arrival_report_path,
      daily_arrival_summaries_path, cotton_bulletins_path, cotton_market_overviews_path,
      cotton_bulletin_path(bulletin), edit_cotton_bulletin_path(bulletin),
      comparison_sheet_cotton_bulletin_path(bulletin),
      grid_cotton_bulletin_cotton_market_observations_path(bulletin, category: "mandi_wise"),
      new_cotton_bulletin_cotton_market_observation_path(bulletin),
      new_cotton_bulletin_cotton_seed_rate_path(bulletin),
      new_cotton_bulletin_candy_rate_path(bulletin),
      new_cotton_bulletin_cotton_regional_comparison_path(bulletin),
      new_cotton_bulletin_cotton_call_performance_path(bulletin),
      states_path, new_state_path, edit_state_path(state),
      districts_path, new_district_path, edit_district_path(district),
      markets_path, new_market_path, edit_market_path(market),
      commodity_groups_path, new_commodity_group_path, edit_commodity_group_path(group),
      commodities_path, new_commodity_path, edit_commodity_path(commodity),
      varieties_path, new_variety_path, edit_variety_path(variety),
      grades_path, new_grade_path, edit_grade_path(grade),
      price_units_path, new_price_unit_path, edit_price_unit_path(price_unit),
      arrival_units_path, new_arrival_unit_path, edit_arrival_unit_path(arrival_unit)
    ]

    failures = []
    paths.each do |path|
      get path
      failures << "#{path} -> #{response.status}" unless response.successful?
      next unless response.successful?

      doc = Nokogiri::HTML(response.body)
      failures << "#{path} -> no .app-topbar" if doc.css(".app-topbar").empty?
      failures << "#{path} -> heading empty" if doc.css(".app-topbar-heading").text.strip.empty?
      failures << "#{path} -> leftover .page-header card" if doc.css(".page-header").any?
    end

    assert_empty failures, failures.join("\n")
  end
end
