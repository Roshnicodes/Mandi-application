require "date"
require "nokogiri"
require "zip"

class DailyPriceArrivalReportExcelImporter
  Result = Data.define(:created, :updated, :skipped, :errors) do
    def success?
      errors.blank?
    end
  end

  HEADERS = [
    "Created On",
    "Arrival Date",
    "State",
    "District",
    "Market",
    "Commodity Group",
    "Commodity",
    "Variety",
    "Grade",
    "Min",
    "Max",
    "Modal",
    "Arrival Qty",
    "Price Unit",
    "Arrival Unit",
    "Reference / Remarks"
  ].freeze

  COMPACT_HEADERS = [
    "Arrival Date",
    "Arrivals",
    "Variety",
    "Minimum Price",
    "Maximum Price",
    "Modal Price"
  ].freeze

  IMPORTED_DISTRICT_NAME = "Imported Markets"
  IMPORTED_COMMODITY_GROUP_NAME = "Imported Commodities"

  def initialize(upload)
    @upload = upload
    @created = 0
    @updated = 0
    @skipped = 0
    @errors = []
  end

  def import
    rows = parse_rows
    return result_with_error("No readable rows were found in the Excel file.") if rows.blank?

    standard_header_index = rows.index { |row| row.map { |value| clean_value(value) }.include?("Arrival Date") && row.map { |value| clean_value(value) }.include?("Market") }
    compact_header_index = rows.index { |row| compact_header_row?(row) }

    if standard_header_index.present?
      import_standard_rows(rows, standard_header_index)
    elsif compact_header_index.present?
      import_compact_rows(rows, compact_header_index)
    else
      return result_with_error("Daily report headers were not found. Upload either a Mandi Pro export or a date-wise commodity price Excel file.")
    end

    Result.new(created: @created, updated: @updated, skipped: @skipped, errors: @errors)
  rescue Zip::Error
    result_with_error("The XLSX file could not be opened. It may be corrupt or use an unsupported format.")
  rescue => error
    Rails.logger.error("Daily report import failed: #{error.class}: #{error.message}")
    result_with_error("The import failed: #{error.message}")
  ensure
    @upload&.tempfile&.rewind if @upload&.respond_to?(:tempfile)
  end

  private
    def import_standard_rows(rows, header_index)
      headers = rows[header_index].map { |value| clean_value(value) }

      ActiveRecord::Base.transaction do
        rows[(header_index + 1)..].to_a.each_with_index do |row, offset|
          import_row(headers, row, header_index + offset + 2)
        end
      end
    end

    def import_compact_rows(rows, header_index)
      context = compact_sheet_context(rows.first(header_index), rows[header_index])
      return @errors << "The commodity or state could not be read from the worksheet title." if context[:commodity_name].blank? || context[:state_name].blank?

      ActiveRecord::Base.transaction do
        state = find_or_create_state(context[:state_name])
        commodity = find_compact_commodity(context[:commodity_name])
        group = commodity&.commodity_group || find_or_create_group(IMPORTED_COMMODITY_GROUP_NAME)
        commodity ||= find_or_create_commodity(group, context[:commodity_name])
        price_unit = find_or_create_price_unit(context[:price_unit])
        arrival_unit = find_or_create_arrival_unit(context[:arrival_unit])
        fallback_district = nil
        current_market = nil
        previous_date = nil

        rows[(header_index + 1)..].to_a.each_with_index do |row, offset|
          row_number = header_index + offset + 2
          values = row.map { |value| clean_value(value) }
          next @skipped += 1 if values.all?(&:blank?)

          if (market_name = compact_market_name(values.first))
            fallback_district ||= find_or_create_district(state, IMPORTED_DISTRICT_NAME)
            current_market = find_or_create_compact_market(state, fallback_district, market_name)
            previous_date = nil
            next
          end

          arrival_date = date_value(values[0]) || previous_date
          previous_date = arrival_date if arrival_date.present?

          if current_market.blank?
            @skipped += 1
            @errors << "Row #{row_number}: no market section was found before this data row."
            next
          end

          import_compact_row(
            values,
            row_number,
            arrival_date: arrival_date,
            market: current_market,
            commodity: commodity,
            price_unit: price_unit,
            arrival_unit: arrival_unit
          )
        end
      end
    end

    def compact_header_row?(row)
      values = row.map { |value| clean_value(value) }
      values.first == "Arrival Date" &&
        values[1].to_s.start_with?("Arrivals") &&
        values[2] == "Variety" &&
        values[3].to_s.start_with?("Minimum Price") &&
        values[4].to_s.start_with?("Maximum Price") &&
        values[5].to_s.start_with?("Modal Price")
    end

    def compact_sheet_context(title_rows, header_row)
      title = title_rows.flatten.map { |value| clean_value(value) }.find { |value| value.match?(/Commodity\s*:/i) && value.match?(/State\s*:/i) }
      match = title.to_s.match(/Commodity\s*:\s*(.+?),\s*State\s*:\s*(.+?)\s*\z/i)
      headers = header_row.map { |value| clean_value(value) }

      {
        commodity_name: match&.[](1)&.squish,
        state_name: match&.[](2)&.squish,
        arrival_unit: parenthesized_unit(headers[1]) || "Metric Tonnes",
        price_unit: parenthesized_unit(headers[3]) || "Rs./Quintal"
      }
    end

    def parenthesized_unit(header)
      header.to_s[/\(([^()]+)\)\s*\z/, 1]&.squish
    end

    def compact_market_name(value)
      value.to_s.match(/\AMarket\s+Name\s*:\s*(.+)\z/i)&.[](1)&.squish
    end

    def import_compact_row(values, row_number, arrival_date:, market:, commodity:, price_unit:, arrival_unit:)
      variety_name = values[2].presence || DailyPriceArrivalReport::DEFAULT_VARIETY_NAME
      variety = find_or_create_variety(commodity, variety_name)
      grade = find_or_create_grade(commodity, variety, DailyPriceArrivalReport::DEFAULT_GRADE_NAME)

      if [ arrival_date, market, commodity, variety, grade, price_unit, arrival_unit ].any?(&:blank?)
        @skipped += 1
        @errors << "Row #{row_number}: required report or master data is missing."
        return
      end

      report = DailyPriceArrivalReport.where(
        arrival_date: arrival_date,
        market: market,
        commodity: commodity,
        variety: variety,
        grade: grade
      ).order(created_at: :desc).first || DailyPriceArrivalReport.new
      was_new = report.new_record?

      report.assign_attributes(
        arrival_date: arrival_date,
        market: market,
        commodity: commodity,
        variety: variety,
        grade: grade,
        price_unit: price_unit,
        arrival_unit: arrival_unit,
        arrival_quantity: decimal_value(values[1]),
        min_price: decimal_value(values[3]),
        max_price: decimal_value(values[4]),
        modal_price: decimal_value(values[5]),
        remarks: "Imported from a date-wise commodity price workbook."
      )

      if report.save
        was_new ? @created += 1 : @updated += 1
      else
        @skipped += 1
        @errors << "Row #{row_number}: #{report.errors.full_messages.to_sentence}"
      end
    end
    def parse_rows
      path = @upload.respond_to?(:path) ? @upload.path : @upload.tempfile.path
      extension = File.extname(@upload.respond_to?(:original_filename) ? @upload.original_filename.to_s : path).downcase

      if extension == ".xlsx" || xlsx_file?(path)
        parse_xlsx(path)
      else
        parse_html_table(path)
      end
    end

    def xlsx_file?(path)
      File.binread(path, 4) == "PK\x03\x04"
    rescue
      false
    end

    def parse_html_table(path)
      document = Nokogiri::HTML(File.read(path))
      table = document.at_css("table")
      return [] unless table

      table.css("tr").map do |row|
        row.css("th,td").flat_map do |cell|
          colspan = cell["colspan"].to_i
          colspan = 1 if colspan < 1
          [ clean_value(cell.text) ] + Array.new(colspan - 1)
        end
      end
    end

    def parse_xlsx(path)
      Zip::File.open(path) do |zip|
        shared_strings = xlsx_shared_strings(zip)
        sheet_entry = zip.glob("xl/worksheets/sheet*.xml").first
        return [] unless sheet_entry

        sheet = Nokogiri::XML(sheet_entry.get_input_stream.read)
        sheet.remove_namespaces!
        sheet.css("row").map do |row|
          cells = []
          row.css("c").each do |cell|
            index = column_index(cell["r"].to_s[/[A-Z]+/])
            cells[index] = xlsx_cell_value(cell, shared_strings)
          end
          cells
        end
      end
    end

    def xlsx_shared_strings(zip)
      entry = zip.find_entry("xl/sharedStrings.xml")
      return [] unless entry

      xml = Nokogiri::XML(entry.get_input_stream.read)
      xml.remove_namespaces!
      xml.css("si").map { |node| clean_value(node.css("t").map(&:text).join) }
    end

    def xlsx_cell_value(cell, shared_strings)
      value = cell.at_css("v")&.text
      return clean_value(cell.at_css("is t")&.text) if value.blank?
      return shared_strings[value.to_i] if cell["t"] == "s"

      clean_value(value)
    end

    def column_index(letters)
      letters.to_s.chars.reduce(0) { |sum, char| (sum * 26) + char.ord - 64 } - 1
    end

    def import_row(headers, row, row_number)
      values = headers.zip(row).to_h.transform_values { |value| clean_value(value) }
      return @skipped += 1 if values.values.all?(&:blank?)

      arrival_date = date_value(values["Arrival Date"])
      state = find_or_create_state(values["State"])
      district = find_or_create_district(state, values["District"])
      market = find_or_create_market(district, values["Market"])
      group = find_or_create_group(values["Commodity Group"])
      commodity = find_or_create_commodity(group, values["Commodity"])
      variety = find_or_create_variety(commodity, values["Variety"])
      grade = find_or_create_grade(commodity, variety, values["Grade"])
      price_unit = find_or_create_price_unit(values["Price Unit"])
      arrival_unit = find_or_create_arrival_unit(values["Arrival Unit"])

      if [ arrival_date, state, district, market, group, commodity, variety, grade, price_unit, arrival_unit ].any?(&:blank?)
        @skipped += 1
        @errors << "Row #{row_number}: required report or master data is missing."
        return
      end

      report = DailyPriceArrivalReport.where(arrival_date: arrival_date, market: market, commodity: commodity, variety: variety, grade: grade).order(created_at: :desc).first
      report ||= DailyPriceArrivalReport.new
      was_new = report.new_record?
      report.assign_attributes(
        arrival_date: arrival_date,
        market: market,
        commodity: commodity,
        variety: variety,
        grade: grade,
        price_unit: price_unit,
        arrival_unit: arrival_unit,
        min_price: decimal_value(values["Min"]),
        max_price: decimal_value(values["Max"]),
        modal_price: decimal_value(values["Modal"]),
        arrival_quantity: decimal_value(values["Arrival Qty"]),
        remarks: values["Reference / Remarks"]
      )

      if report.save
        was_new ? @created += 1 : @updated += 1
      else
        @skipped += 1
        @errors << "Row #{row_number}: #{report.errors.full_messages.to_sentence}"
      end
    end

    def find_or_create_state(name)
      return if name.blank?

      State.where("LOWER(name) = ?", name.downcase).first || State.create!(name: name)
    end

    def find_or_create_district(state, name)
      return if state.blank? || name.blank?

      District.where(state: state).where("LOWER(name) = ?", name.downcase).first || District.create!(state: state, name: name)
    end

    def find_or_create_market(district, name)
      return if district.blank? || name.blank?

      Market.where(district: district).where("LOWER(name) = ?", name.downcase).first || Market.create!(district: district, name: name)
    end

    def find_or_create_compact_market(state, fallback_district, name)
      normalized_name = normalized_market_name(name)
      @compact_market_indexes ||= {}
      market_index = @compact_market_indexes[state.id] ||= Market.includes(district: :state)
        .joins(district: :state)
        .where(states: { id: state.id })
        .index_by { |market| normalized_market_name(market.name) }

      existing_market = market_index[normalized_name]
      return existing_market if existing_market

      find_or_create_market(fallback_district, name).tap do |market|
        market_index[normalized_name] = market
      end
    end

    def normalized_market_name(name)
      name.to_s.downcase
        .gsub(/agriculture\s+produce\s+market\s+committee/, "")
        .gsub(/agricultural\s+produce\s+market\s+committee/, "")
        .gsub(/\bapmc\b/, "")
        .gsub(/[^a-z0-9]/, "")
    end

    def find_or_create_group(name)
      return if name.blank?

      CommodityGroup.where("LOWER(name) = ?", name.downcase).first || CommodityGroup.create!(name: name)
    end

    def find_or_create_commodity(group, name)
      return if group.blank? || name.blank?

      Commodity.where(commodity_group: group).where("LOWER(name) = ?", name.downcase).first || Commodity.create!(commodity_group: group, name: name)
    end

    def find_compact_commodity(name)
      normalized_name = normalized_commodity_name(name)
      Commodity.includes(:commodity_group).find do |commodity|
        normalized_commodity_name(commodity.name) == normalized_name || compact_commodity_alias_match?(commodity.name, name)
      end
    end

    def normalized_commodity_name(name)
      name.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    def compact_commodity_alias_match?(existing_name, imported_name)
      existing_tokens = existing_name.to_s.downcase.scan(/[a-z]+/)
      imported_tokens = imported_name.to_s.downcase.scan(/[a-z]+/)
      identifying_tokens = %w[arhar tur red gram cotton kapas wheat paddy rice maize soybean mustard]

      (existing_tokens & imported_tokens & identifying_tokens).size >= 2
    end

    def find_or_create_variety(commodity, name)
      return if commodity.blank? || name.blank?

      @variety_cache ||= {}
      cache_key = [ commodity.id, name.downcase ]
      @variety_cache[cache_key] ||= Variety.where(commodity: commodity).where("LOWER(name) = ?", name.downcase).first || Variety.create!(commodity: commodity, name: name)
    end

    def find_or_create_grade(commodity, variety, name)
      return if commodity.blank? || name.blank?

      @grade_cache ||= {}
      cache_key = [ commodity.id, variety&.id, name.downcase ]
      @grade_cache[cache_key] ||= Grade.where(commodity: commodity, variety: variety).where("LOWER(name) = ?", name.downcase).first || Grade.create!(commodity: commodity, variety: variety, name: name)
    end

    def find_or_create_price_unit(name)
      return PriceUnit.ordered.first if name.blank?

      PriceUnit.where("LOWER(name) = ? OR LOWER(short_name) = ?", name.downcase, name.downcase).first || PriceUnit.create!(name: name, short_name: name)
    end

    def find_or_create_arrival_unit(name)
      return ArrivalUnit.ordered.first if name.blank?

      ArrivalUnit.where("LOWER(name) = ? OR LOWER(short_name) = ?", name.downcase, name.downcase).first || ArrivalUnit.create!(name: name, short_name: name)
    end

    def date_value(value)
      return if value.blank?
      return Date.new(1899, 12, 30) + value.to_i if value.to_s.match?(/\A\d+(\.0)?\z/) && value.to_i > 20_000

      Date.parse(value.to_s)
    rescue
      nil
    end

    def decimal_value(value)
      BigDecimal(value.to_s.gsub(/[^\d.\-]/, ""))
    rescue
      nil
    end

    def clean_value(value)
      value.to_s.gsub(/\u00A0/, " ").squish
    end

    def result_with_error(message)
      Result.new(created: @created, updated: @updated, skipped: @skipped, errors: [ message ])
    end
end
