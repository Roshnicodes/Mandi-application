require "test_helper"

class DownloadPermissionsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @regular_user = users(:two)
    @bulletin = CottonBulletin.create!(report_date: Date.current, title: "Test Cotton Bulletin")
  end

  test "regular user can download daily report excel but cannot import or create" do
    sign_in_as(@regular_user)

    get export_daily_price_arrival_reports_path
    assert_response :success
    assert_equal "application/vnd.ms-excel", response.media_type

    post import_daily_price_arrival_reports_path
    assert_redirected_to root_path

    get new_daily_price_arrival_report_path
    assert_redirected_to root_path
  end

  test "regular user can download cotton excel but cannot import or create" do
    sign_in_as(@regular_user)

    get export_cotton_bulletin_path(@bulletin)
    assert_response :success
    assert_equal "application/vnd.ms-excel", response.media_type

    post import_cotton_bulletin_path(@bulletin)
    assert_redirected_to root_path

    get new_cotton_bulletin_path
    assert_redirected_to root_path
  end

  test "admin can import entry points" do
    sign_in_as(@admin)

    post import_daily_price_arrival_reports_path
    assert_redirected_to daily_price_arrival_reports_path

    post import_cotton_bulletin_path(@bulletin)
    assert_redirected_to cotton_bulletin_path(@bulletin)
  end
end
