require "test_helper"

class Api::V1::RatesApiTest < ActionDispatch::IntegrationTest
  TOKEN = "test-api-token".freeze

  setup do
    @previous_token = ENV["MANDI_API_TOKEN"]
    ENV["MANDI_API_TOKEN"] = TOKEN

    @state = State.create!(name: "Madhya Pradesh")
    @district = District.create!(state: @state, name: "Agar")
    @market = Market.create!(district: @district, name: "Agar")
    group = CommodityGroup.create!(name: "Oilseeds")
    @commodity = Commodity.create!(commodity_group: group, name: "Soybean")
    variety = Variety.create!(commodity: @commodity, name: "Other")
    grade = Grade.create!(commodity: @commodity, variety: variety, name: "Non-FAQ")
    price_unit = PriceUnit.create!(name: "Rs./Quintal", short_name: "Rs./Quintal")
    arrival_unit = ArrivalUnit.create!(name: "Qtl", short_name: "Qtl")

    base = { state: @state, district: @district, market: @market, commodity_group: group, commodity: @commodity,
             variety: variety, grade: grade, price_unit: price_unit, arrival_unit: arrival_unit, remarks: "agmarknet" }
    @older = DailyPriceArrivalReport.create!(base.merge(arrival_date: Date.new(2026, 9, 28), arrival_quantity: 100, min_price: 4000, max_price: 5000, modal_price: 4500))
    @latest = DailyPriceArrivalReport.create!(base.merge(arrival_date: Date.new(2026, 9, 29), arrival_quantity: 9995, min_price: 1925, max_price: 5750, modal_price: 5300))
  end

  teardown do
    ENV["MANDI_API_TOKEN"] = @previous_token
  end

  test "rejects requests without a valid token" do
    get api_v1_daily_rates_path
    assert_response :unauthorized

    get api_v1_cotton_rates_path, headers: auth("wrong")
    assert_response :unauthorized
    assert_equal "Missing or invalid API token.", response.parsed_body["error"]
  end

  test "stays closed when no token is configured" do
    ENV["MANDI_API_TOKEN"] = nil

    get api_v1_daily_rates_path, headers: auth("")
    assert_response :service_unavailable
  end

  test "daily rates default to the latest report date" do
    @latest.attachments.attach(io: StringIO.new("sheet"), filename: "agar.pdf", content_type: "application/pdf")

    get api_v1_daily_rates_path, headers: auth

    assert_response :success
    body = response.parsed_body
    assert_equal "2026-09-29", body["from_date"]
    assert_equal 1, body["total_count"]
    rate = body["rates"].first
    assert_equal "Agar", rate.dig("market", "name")
    assert_equal "Soybean", rate.dig("commodity", "name")
    assert_equal [ 1925.0, 5750.0, 5300.0 ], rate.values_at("min_price", "max_price", "modal_price")
    assert_equal "Rs./Quintal", rate["price_unit"]
    assert_equal 9995.0, rate["arrival_quantity"]
    assert_equal "agar.pdf", rate.dig("attachments", 0, "filename")
    assert_match %r{/rails/active_storage/blobs/}, rate.dig("attachments", 0, "url")
  end

  test "daily rates filter by date range, commodity and paginate" do
    get api_v1_daily_rates_path(from_date: "2026-09-28", to_date: "2026-09-29", commodity_id: @commodity.id, per_page: 1, page: 2), headers: auth

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body["total_count"]
    assert_equal 2, body["total_pages"]
    assert_equal [ "2026-09-28" ], body["rates"].map { |rate| rate["arrival_date"] }

    get api_v1_daily_rates_path(date: "2026-09-28"), headers: auth
    assert_equal [ @older.id ], response.parsed_body["rates"].map { |rate| rate["id"] }
  end

  test "daily rates reject a bad date" do
    get api_v1_daily_rates_path(date: "29-09-2026"), headers: auth

    assert_response :bad_request
    assert_match(/date must be a date like/, response.parsed_body["error"])
  end

  test "cotton rates return the latest bulletin with rates, skipping empty ones" do
    bulletin = CottonBulletin.create!(report_date: Date.new(2026, 9, 29), title: "Cotton Market Report")
    bulletin.cotton_market_observations.create!(category: "mandi_wise", name: "Agar", market: @market, position: 1,
      arrival_quantity: 645, minimum_price: 7700, maximum_price: 8525, modal_price: 8200)
    bulletin.candy_rates.create!(category: "mch", parameter: "Candy rate", madhya_pradesh_rate: "55500")
    bulletin.cotton_seed_rates.create!(particular: "Cotton seed", madhya_pradesh_rate: "3400")
    CottonBulletin.create!(report_date: Date.new(2026, 10, 1), title: "Empty day")

    get api_v1_cotton_rates_path, headers: auth

    assert_response :success
    body = response.parsed_body
    assert_equal "2026-09-29", body["report_date"]
    row = body.dig("raw_cotton_rates", "mandi_wise", "rows", 0)
    assert_equal "Agar", row["name"]
    assert_equal "Madhya Pradesh", row.dig("state", "name")
    assert_equal [ 7700.0, 8525.0, 8200.0 ], row.values_at("minimum_price", "maximum_price", "modal_price")
    assert_equal "CCI Mandi Rates", body.dig("raw_cotton_rates", "cci_mandi", "label")
    assert_equal "55500", body.dig("candy_rates", "mch", "rows", 0, "madhya_pradesh_rate")
    assert_equal "3400", body.dig("cotton_seed_rates", 0, "madhya_pradesh_rate")
    assert_not body["raw_cotton_rates"].key?("comparison_sheet")
  end

  test "cotton rates for a missing date return 404" do
    get api_v1_cotton_rates_path(date: "2026-01-01"), headers: auth

    assert_response :not_found
  end

  private
    def auth(token = TOKEN)
      { "Authorization" => "Bearer #{token}" }
    end
end
