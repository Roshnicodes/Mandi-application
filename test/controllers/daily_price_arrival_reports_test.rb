require "test_helper"

class DailyPriceArrivalReportsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @regular_user = users(:two)
    @state = State.create!(name: "Madhya Pradesh")
    @district = District.create!(state: @state, name: "Agar")
    @market = Market.create!(district: @district, name: "Agar")
    @group = CommodityGroup.create!(name: "Oilseeds")
    @commodity = Commodity.create!(commodity_group: @group, name: "Soybean")
    @variety = Variety.create!(commodity: @commodity, name: "Other")
    @grade = Grade.create!(commodity: @commodity, variety: @variety, name: "Non-FAQ")
    @price_unit = PriceUnit.create!(name: "Rs./Quintal", short_name: "Rs./Quintal")
    @arrival_unit = ArrivalUnit.create!(name: "Qtl", short_name: "Qtl")

    @report = DailyPriceArrivalReport.create!(
      arrival_date: Date.new(2026, 9, 29),
      state: @state,
      district: @district,
      market: @market,
      commodity_group: @group,
      commodity: @commodity,
      variety: @variety,
      grade: @grade,
      price_unit: @price_unit,
      arrival_unit: @arrival_unit,
      arrival_quantity: 9995,
      min_price: 1925,
      max_price: 5750,
      modal_price: 5300,
      remarks: "agmarknet"
    )
  end

  test "regular user can create a report but cannot edit or delete a saved report" do
    sign_in_as(@regular_user)

    assert_difference("DailyPriceArrivalReport.count", 1) do
      post daily_price_arrival_reports_path, params: { daily_price_arrival_report: report_params }
    end
    assert_redirected_to new_daily_price_arrival_report_path(
      state_id: @state.id,
      district_id: @district.id,
      market_id: @market.id,
      commodity_group_id: @group.id,
      commodity_id: @commodity.id,
      variety_id: @variety.id,
      grade_id: @grade.id,
      price_unit_id: @price_unit.id,
      arrival_unit_id: @arrival_unit.id
    )

    get edit_daily_price_arrival_report_path(@report)
    assert_redirected_to root_path

    assert_no_difference("DailyPriceArrivalReport.count") do
      delete daily_price_arrival_report_path(@report)
    end
    assert_redirected_to root_path
  end

  test "renders saved reports in the APMC daily sheet layout" do
    sign_in_as(@admin)

    get daily_price_arrival_reports_path

    assert_response :success
    assert_select ".daily-reports-page"
    assert_select ".daily-report-commandbar"
    assert_select "form.daily-upload-bar"
    assert_select ".page-hero .page-hero-heading h1", text: "Daily Mandi Reports"
    assert_select ".filter-bar input[placeholder=?]", "From date"
    assert_select ".daily-mandi-sheet-footer", text: /Showing 1 to \d+ of \d+ records/
    assert_select "th a.daily-sort-link", text: /Modal Price/
    assert_select "table.daily-mandi-table", count: 1
    assert_select "table.daily-mandi-table th", text: /APMC/
    assert_select "table.daily-mandi-table td", text: /Agar/
    assert_select "table.daily-mandi-table td", text: /agmarknet/
  end

  test "search narrows the sheet by mandi, commodity or reference" do
    sign_in_as(@admin)

    get daily_price_arrival_reports_path(q: "Agar")
    assert_response :success
    assert_select "table.daily-mandi-table td", text: /Agar/

    get daily_price_arrival_reports_path(q: "agmarknet")
    assert_response :success
    assert_select "table.daily-mandi-table", count: 1

    get daily_price_arrival_reports_path(q: "Soybean")
    assert_response :success
    assert_select "table.daily-mandi-table", count: 1

    get daily_price_arrival_reports_path(q: "no-such-mandi")
    assert_response :success
    assert_select "table.daily-mandi-table", count: 0
    assert_select ".daily-report-empty-state"
  end

  test "search sits in the filter bar and survives alongside the other filters" do
    sign_in_as(@admin)

    get daily_price_arrival_reports_path(q: "Agar", from_date: "2026-09-29", to_date: "2026-09-29")

    assert_response :success
    assert_select ".filter-bar-search input[name=?][value=?]", "q", "Agar"
    assert_select "table.daily-mandi-table", count: 1
  end

  test "exports the APMC daily sheet layout" do
    sign_in_as(@admin)

    get export_daily_price_arrival_reports_path

    assert_response :success
    assert_equal "application/vnd.ms-excel", response.media_type
    assert_match(/Soybean Commodity Arrival and Rates - 29th Sep, 2026 State - MP/, response.body)
    assert_match(/Arrivals<br>\(In Qtl\)/, response.body)
  end

  test "exports attachment download links" do
    sign_in_as(@admin)
    @report.attachments.attach(io: StringIO.new("mandi sheet"), filename: "agar-sheet.pdf", content_type: "application/pdf")

    get export_daily_price_arrival_reports_path

    assert_response :success
    assert_match(/<th class="column-heading">Attachments<\/th>/, response.body)
    assert_match(%r{<a href="http://www\.example\.com/rails/active_storage/blobs/redirect/[^"]+/agar-sheet\.pdf\?disposition=attachment">agar-sheet\.pdf</a>}, response.body)
  end

  private
    def report_params
      {
        arrival_date: Date.new(2026, 9, 30),
        state_id: @state.id,
        district_id: @district.id,
        market_id: @market.id,
        commodity_group_id: @group.id,
        commodity_id: @commodity.id,
        variety_id: @variety.id,
        grade_id: @grade.id,
        price_unit_id: @price_unit.id,
        arrival_unit_id: @arrival_unit.id,
        arrival_quantity: 100,
        min_price: 1000,
        max_price: 1200,
        modal_price: 1100,
        remarks: "manual entry"
      }
    end
end
