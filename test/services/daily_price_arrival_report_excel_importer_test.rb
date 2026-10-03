require "test_helper"
require "tempfile"
require "zip"

class DailyPriceArrivalReportExcelImporterTest < ActiveSupport::TestCase
  test "imports every APMC commodity block and safely skips dash-only rows" do
    state = State.create!(name: "Madhya Pradesh")
    agar_district = District.create!(state: state, name: "Agar")
    betul_district = District.create!(state: state, name: "Betul")
    Market.create!(district: agar_district, name: "Agar")
    Market.create!(district: betul_district, name: "Betul")

    workbook = Tempfile.new([ "apmc-daily-sheet", ".xls" ])
    workbook.write(<<~HTML)
      <html><body>
        <table>
          <tr><th colspan="6">Soybean Commodity Arrival and Rates - 29th Sep, 2026 State - MP</th></tr>
          <tr><th>APMC</th><th>Arrivals (In Qtl)</th><th>Minimum Price (Rs./Quintal)</th><th>Maximum Price (Rs./Quintal)</th><th>Modal Price (Rs./Quintal)</th><th>Reference</th></tr>
          <tr><td>Agar</td><td>9995</td><td>1925</td><td>5750</td><td>5300</td><td>agmarknet</td></tr>
          <tr><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td></tr>
        </table>
        <table>
          <tr><th colspan="6">Maize Commodity Arrival and Rates - 29th Sep, 2026 - State MP</th></tr>
          <tr><th>APMC</th><th>Arrivals (In Qtl)</th><th>Minimum Price (Rs./Quintal)</th><th>Maximum Price (Rs./Quintal)</th><th>Modal Price (Rs./Quintal)</th><th>Reference</th></tr>
          <tr><td>Betul</td><td>330</td><td>1751</td><td>2600</td><td>2500</td><td>APMC Daily Mandi Sheet</td></tr>
        </table>
      </body></html>
    HTML
    workbook.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: workbook,
      filename: "daily-mandi.xls",
      type: "application/vnd.ms-excel"
    )

    result = DailyPriceArrivalReportExcelImporter.new(upload).import

    assert result.success?, result.errors.to_sentence
    assert_equal 2, result.created
    assert_equal 0, result.updated
    assert_equal 1, result.skipped
    assert_equal 2, DailyPriceArrivalReport.count

    soybean_report = DailyPriceArrivalReport.joins(:commodity).find_by!(commodities: { name: "Soybean" })
    assert_equal state, soybean_report.state
    assert_equal "Agar", soybean_report.market.name
    assert_equal Date.new(2026, 9, 29), soybean_report.arrival_date
    assert_equal 9995, soybean_report.arrival_quantity
    assert_equal 5300, soybean_report.modal_price
    assert_equal "agmarknet", soybean_report.remarks
    assert_equal "Qtl", soybean_report.arrival_unit.short_name

    second_result = DailyPriceArrivalReportExcelImporter.new(upload).import
    assert second_result.success?, second_result.errors.to_sentence
    assert_equal 0, second_result.created
    assert_equal 2, second_result.updated
    assert_equal 2, DailyPriceArrivalReport.count
  ensure
    workbook&.close!
  end

  test "scans every worksheet in an xlsx daily workbook" do
    state = State.create!(name: "Madhya Pradesh")
    district = District.create!(state: state, name: "Dhar")
    Market.create!(district: district, name: "Kukshi")

    workbook = Tempfile.new([ "apmc-daily-workbook", ".xlsx" ])
    workbook.close

    Zip::File.open(workbook.path, create: true) do |zip|
      zip.get_output_stream("xl/worksheets/sheet1.xml") { |stream| stream.write(apmc_sheet_xml("Soybean", "Kukshi", "1460", "4300", "5700", "5151")) }
      zip.get_output_stream("xl/worksheets/sheet2.xml") { |stream| stream.write(apmc_sheet_xml("Maize", "Kukshi", "9220", "1450", "2201", "1900")) }
    end

    workbook.open
    workbook.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: workbook,
      filename: "daily-mandi.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )

    result = DailyPriceArrivalReportExcelImporter.new(upload).import

    assert result.success?, result.errors.to_sentence
    assert_equal 2, result.created
    assert_equal 2, DailyPriceArrivalReport.count
    assert_equal %w[Maize Soybean], DailyPriceArrivalReport.joins(:commodity).order("commodities.name").pluck("commodities.name")
  ensure
    workbook&.close!
  end

test "imports embedded date-wise rows and State UT worksheets without errors" do
  state = State.create!(name: "Madhya Pradesh")
  district = District.create!(state: state, name: "Agar")
  Market.create!(district: district, name: "Agar")

  workbook = Tempfile.new([ "mixed-daily-sheet", ".xls" ])
  workbook.write(<<~HTML)
    <html><body>
      <table>
        <tr><th colspan="7">Soybean Commodity Arrival and Rates - 29th Sep, 2026 State - MP</th></tr>
        <tr><th>APMC</th><th>Arrivals (In Qtl)</th><th>Variety Soy / Yellow Soy)</th><th>Minimum Price (Rs./Quintal)</th><th>Maximum Price (Rs./Quintal)</th><th>Modal Price (Rs./Quintal)</th><th>Reference</th></tr>
        <tr><td>Market Name : Agar APMC</td><td></td><td></td><td></td><td></td><td></td><td></td></tr>
        <tr><td>09/09/2026</td><td>78.633</td><td>Soyabeen</td><td>3771</td><td>6001</td><td>5944</td><td></td></tr>
        <tr><td></td><td>1.5</td><td>Yellow Soybean</td><td>5450</td><td>5450</td><td>5450</td><td></td></tr>
        <tr><td>Agar</td><td>9995</td><td>Soybean</td><td>1925</td><td>5750</td><td>5300</td><td>agmarknet</td></tr>
        <tr><td>Khargone</td><td>15560</td><td>Local</td><td>1516</td><td>2305</td><td>650</td><td>APMC Daily Mandi Sheet</td></tr>
      </table>
      <table>
        <tr><th colspan="6">Commodity : Maize, State/UT : Madhya Pradesh</th></tr>
        <tr><th>Arrival Date</th><th>Arrivals (Metric Tonnes)</th><th>Variety</th><th>Minimum Price (Rs./Quintal)</th><th>Maximum Price (Rs./Quintal)</th><th>Modal Price (Rs./Quintal)</th></tr>
        <tr><td>Market Name : Agar APMC</td><td></td><td></td><td></td><td></td><td></td></tr>
        <tr><td>07/09/2026</td><td>0.445</td><td>Local</td><td>2112</td><td>2112</td><td>2112</td></tr>
      </table>
    </body></html>
  HTML
  workbook.rewind

  upload = ActionDispatch::Http::UploadedFile.new(
    tempfile: workbook,
    filename: "mixed-daily-sheet.xls",
    type: "application/vnd.ms-excel"
  )

  result = DailyPriceArrivalReportExcelImporter.new(upload).import

  assert result.success?, result.errors.to_sentence
  assert_equal 4, result.created
  assert_equal 1, result.skipped
  assert_equal 4, DailyPriceArrivalReport.count
  assert DailyPriceArrivalReport.exists?(arrival_date: Date.new(2026, 9, 9), commodity: Commodity.find_by!(name: "Soybean"))
  assert DailyPriceArrivalReport.exists?(arrival_date: Date.new(2026, 9, 7), commodity: Commodity.find_by!(name: "Maize"))
ensure
  workbook&.close!
end

  test "maps known MP APMCs to their district when the source has no district column" do
    workbook = Tempfile.new([ "mapped-apmc-sheet", ".xls" ])
    workbook.write(<<~HTML)
      <html><body><table>
        <tr><th colspan="6">Maize Commodity Arrival and Rates - 29th Sep, 2026 State - MP</th></tr>
        <tr><th>APMC</th><th>Arrivals (In Qtl)</th><th>Variety</th><th>Minimum Price (Rs./Quintal)</th><th>Maximum Price (Rs./Quintal)</th><th>Modal Price (Rs./Quintal)</th></tr>
        <tr><td>Anjad APMC</td><td>1244</td><td>Local</td><td>1400</td><td>2300</td><td>1700</td></tr>
      </table></body></html>
    HTML
    workbook.rewind

    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: workbook,
      filename: "mapped-apmc-sheet.xls",
      type: "application/vnd.ms-excel"
    )

    result = DailyPriceArrivalReportExcelImporter.new(upload).import

    assert result.success?, result.errors.to_sentence
    report = DailyPriceArrivalReport.last
    assert_equal "Barwani", report.district.name
    assert_equal "Anjad", report.market.name
    assert_not District.exists?(name: "Imported Markets")
  ensure
    workbook&.close!
  end

  private
    def apmc_sheet_xml(commodity, market, arrivals, minimum, maximum, modal)
      headers = [
        "APMC",
        "Arrivals (In Qtl)",
        "Minimum Price (Rs./Quintal)",
        "Maximum Price (Rs./Quintal)",
        "Modal Price (Rs./Quintal)",
        "Reference"
      ]
      title = "#{commodity} Commodity Arrival and Rates - 29th Sep, 2026 State - MP"

      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1"><c r="A1" t="inlineStr"><is><t>#{title}</t></is></c></row>
            <row r="2">#{headers.each_with_index.map { |value, index| xlsx_inline_cell((65 + index).chr, 2, value) }.join}</row>
            <row r="3">#{xlsx_inline_cell("A", 3, market)}<c r="B3"><v>#{arrivals}</v></c><c r="C3"><v>#{minimum}</v></c><c r="D3"><v>#{maximum}</v></c><c r="E3"><v>#{modal}</v></c>#{xlsx_inline_cell("F", 3, "agmarknet")}</row>
          </sheetData>
        </worksheet>
      XML
    end

    def xlsx_inline_cell(column, row, value)
      "<c r=\"#{column}#{row}\" t=\"inlineStr\"><is><t>#{ERB::Util.html_escape(value)}</t></is></c>"
    end
end
