require "test_helper"

class CottonBulletinsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @report_date = Date.new(2030, 1, 15)
  end

  test "opens a daily cotton report directly and reuses its date" do
    sign_in_as(@admin)

    assert_difference("CottonBulletin.count", 1) do
      post start_cotton_bulletins_path, params: { report_date: @report_date }
    end

    bulletin = CottonBulletin.find_by!(report_date: @report_date)
    assert_equal "Cotton Market Report · 15 Jan 2030", bulletin.title
    assert_redirected_to cotton_bulletin_path(bulletin)

    assert_no_difference("CottonBulletin.count") do
      post start_cotton_bulletins_path, params: { report_date: @report_date }
    end

    assert_redirected_to cotton_bulletin_path(bulletin)
  end

  test "imports every dated sheet of a workbook into its own daily report" do
    sign_in_as(@admin)

    file = fixture_file_upload("cotton_two_dates.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    assert_difference("CottonBulletin.count", 2) do
      post import_daily_cotton_bulletins_path, params: { excel_file: file, report_date: @report_date }
    end

    assert_redirected_to cotton_bulletins_path

    first = CottonBulletin.find_by!(report_date: Date.new(2030, 1, 5))
    second = CottonBulletin.find_by!(report_date: Date.new(2030, 1, 6))

    assert_equal [ "Kukshi" ], first.observations_for("mandi_wise").map(&:name)
    assert_equal [ "Anjad" ], second.observations_for("mandi_wise").map(&:name)
    assert_equal 3108, first.observations_for("mandi_wise").first.arrival_quantity

    # The two-row candy header splits MP into 29 MM and 30 MM columns.
    rate = first.candy_rates_for("mch").first
    assert_equal "RD - 75", rate.parameter
    assert_equal "66000-66300", rate.madhya_pradesh_29mm_rate
    assert_equal "67000-67300", rate.madhya_pradesh_rate
    assert_equal "68300-68500", rate.odisha_29mm_rate

    assert_equal "70000-72000", first.candy_rates_for("dch").first.madhya_pradesh_rate
    assert_equal "4350-4550", first.cotton_seed_rates.first.odisha_rate
  end

  test "importing the same workbook twice updates rather than duplicates" do
    sign_in_as(@admin)

    2.times do
      post import_daily_cotton_bulletins_path, params: {
        excel_file: fixture_file_upload("cotton_two_dates.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
        report_date: @report_date
      }
    end

    assert_equal 2, CottonBulletin.where(report_date: [ Date.new(2030, 1, 5), Date.new(2030, 1, 6) ]).count
    assert_equal 1, CottonBulletin.find_by!(report_date: Date.new(2030, 1, 5)).observations_for("mandi_wise").count
  end

  test "keeps candy parameters out of the mandi list when re-importing an export" do
    sign_in_as(@admin)

    bulletin = CottonBulletin.daily_for(@report_date)
    rows = [
      [ "Mandi Wise" ],
      [ "S. No", "Mandi Name", "Arrival Qty", "Minimum Price", "Maximum Price", "Modal Price", "Reference" ],
      [ "1", "Kukshi", "108", "6990", "6999", "6990", "Kukshi APMC" ],
      [ "2", "Ratlam - DCH", "-", "-", "-", "-", "Ratlam APMC" ],
      [ "3", "RD - 75", "-", "54300", "-", "-", "-" ],
      [ "Cotton Seed Rate" ]
    ]

    CottonBulletinExcelImporter.new(bulletin, nil, rows: rows).import

    names = bulletin.observations_for("mandi_wise").map(&:name)
    assert_includes names, "Kukshi"
    assert_includes names, "Ratlam - DCH", "a mandi whose name ends in DCH is still a mandi"
    assert_not_includes names, "RD - 75"
  end

  test "search and date range narrow the saved report list" do
    sign_in_as(@admin)

    CottonBulletin.daily_for(Date.new(2030, 3, 5))
    CottonBulletin.daily_for(Date.new(2030, 4, 20))

    get cotton_bulletins_path(q: "05 Mar 2030")
    assert_response :success
    assert_select ".filter-bar-search input[name=?]", "q"
    assert_select "table.cotton-index-table tbody tr", count: 1

    get cotton_bulletins_path(from_date: "2030-04-01", to_date: "2030-04-30")
    assert_response :success
    assert_select "table.cotton-index-table tbody tr", count: 1

    get cotton_bulletins_path(q: "no such report")
    assert_response :success
    assert_select "table.cotton-index-table", count: 0
  end

  test "the report page offers an in-sheet search and no market update link" do
    sign_in_as(@admin)
    bulletin = CottonBulletin.daily_for(@report_date)

    get cotton_bulletin_path(bulletin)

    assert_response :success
    assert_select "input[data-sheet-search]"
    assert_select "[data-sheet-section]", minimum: 1
    assert_select "a", text: /Market Update/, count: 0
  end

  test "the saved report list no longer links to market update" do
    sign_in_as(@admin)
    CottonBulletin.daily_for(@report_date)

    get cotton_bulletins_path

    assert_response :success
    assert_select "a", text: /Market Update/, count: 0
  end

  test "redirects the legacy new page to direct daily entry" do
    sign_in_as(@admin)

    get new_cotton_bulletin_path

    assert_redirected_to cotton_bulletins_path
  end
end
