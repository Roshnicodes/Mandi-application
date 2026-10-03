require "date"
require "nokogiri"
require "zip"

class CottonBulletinExcelImporter
  Result = Data.define(:created, :updated, :skipped, :errors) do
    def imported_count
      created + updated
    end

    def success?
      errors.blank?
    end
  end

  # One upload usually carries a whole month of daily sheets, so a workbook
  # import reports what landed on each date rather than a single total.
  WorkbookResult = Data.define(:bulletins, :created, :updated, :skipped, :errors, :skipped_sheets) do
    def imported_count
      created + updated
    end

    def success?
      errors.blank?
    end

    def dates
      bulletins.map(&:report_date).sort
    end

    def date_range_label
      return if dates.empty?
      return dates.first.strftime("%d %b %Y") if dates.one?

      "#{dates.first.strftime("%d %b")} - #{dates.last.strftime("%d %b %Y")}"
    end
  end

  # Imports every dated sheet of a workbook into the cotton report for that
  # sheet's own date, creating the daily reports that do not exist yet.
  def self.import_workbook(upload, fallback_date: Date.current)
    parser = CottonExcelWorkbookParser.new(upload)
    sheets = parser.sheets
    return WorkbookResult.new(bulletins: [], created: 0, updated: 0, skipped: 0, errors: [ "No readable sheets were found in the Excel file." ], skipped_sheets: []) if sheets.blank?

    importable = parser.dated_sheets
    # A single-sheet workbook without a recognisable date still belongs to the
    # date the user picked on the form.
    importable = sheets.reject(&:hidden).first(1) if importable.empty?

    bulletins = []
    created = updated = skipped = 0
    errors = []

    importable.each do |sheet|
      bulletin = CottonBulletin.daily_for(sheet.report_date || fallback_date)
      result = new(bulletin, nil, rows: sheet.rows).import

      bulletins << bulletin
      created += result.created
      updated += result.updated
      skipped += result.skipped
      errors.concat(result.errors.map { |message| "#{sheet.name || "Sheet"}: #{message}" })
    end

    skipped_sheets = sheets.select(&:hidden).filter_map(&:name)

    WorkbookResult.new(
      bulletins: bulletins.uniq,
      created: created,
      updated: updated,
      skipped: skipped,
      errors: errors,
      skipped_sheets: skipped_sheets
    )
  rescue Zip::Error
    WorkbookResult.new(bulletins: [], created: 0, updated: 0, skipped: 0, errors: [ "The XLSX file could not be opened. It may be corrupt or use an unsupported format." ], skipped_sheets: [])
  rescue => error
    Rails.logger.error("Cotton workbook import failed: #{error.class}: #{error.message}")
    WorkbookResult.new(bulletins: [], created: 0, updated: 0, skipped: 0, errors: [ "The import failed: #{error.message}" ], skipped_sheets: [])
  end

  def initialize(bulletin, upload, rows: nil)
    @bulletin = bulletin
    @upload = upload
    @rows = rows
    @created = 0
    @updated = 0
    @skipped = 0
    @errors = []
  end

  def import
    rows = @rows || parse_rows
    return result_with_error("No readable rows were found in the Excel file.") if rows.blank?

    ActiveRecord::Base.transaction do
      import_market_rows(rows)
      import_seed_rows(rows)
      import_candy_rows(rows, "mch", "Candy Rate (MCH)")
      import_candy_rows(rows, "dch", "Candy Rate (DCH)")
      import_regional_rows(rows)
      import_call_rows(rows)
      import_comparison_rows(rows)
    end

    Result.new(created: @created, updated: @updated, skipped: @skipped, errors: @errors)
  rescue Zip::Error
    result_with_error("The XLSX file could not be opened. It may be corrupt or use an unsupported format.")
  rescue => error
    Rails.logger.error("Cotton bulletin import failed: #{error.class}: #{error.message}")
    result_with_error("The import failed: #{error.message}")
  ensure
    @upload&.tempfile&.rewind if @upload&.respond_to?(:tempfile)
  end

  private
    # A workbook uploaded from a single report page may still hold many dated
    # sheets, so pick the one that belongs to this report before falling back
    # to the first visible sheet.
    def parse_rows
      parser = CottonExcelWorkbookParser.new(@upload)
      sheets = parser.sheets
      return [] if sheets.blank?

      sheet = sheets.find { |candidate| candidate.report_date == @bulletin.report_date }
      sheet ||= sheets.reject(&:hidden).first || sheets.first
      sheet.rows
    end

    def import_market_rows(rows)
      left_rows = rows_between(rows, "Mandi Wise", "Cotton Seed Rate")
      left_rows.each do |row|
        next unless row[1].present? && numericish?(row[0])
        next if rate_parameter_name?(row[1])

        name = row[1]
        category = name.include?("CCI") ? "cci_mandi" : "mandi_wise"
        upsert_observation(
          category,
          name,
          position: integer_value(row[0]),
          arrival_quantity: decimal_value(row[2]),
          minimum_price: decimal_value(row[3]),
          maximum_price: decimal_value(row[4]),
          modal_price: decimal_value(row[5]),
          remarks: row[6]
        )
      end

      right_rows = rows_between(rows, "GIN Wise", "Cotton Seed Rate")
      right_rows.each do |row|
        next unless row[9].present? && numericish?(row[8])
        next if rate_parameter_name?(row[9])

        upsert_observation(
          "gin_wise",
          row[9],
          position: integer_value(row[8]),
          arrival_quantity: decimal_value(row[10]),
          moisture: row[11],
          arrival_price: row[12],
          remarks: row[13]
        )
      end
    end

    def import_seed_rows(rows)
      section = rows_between(rows, "Cotton Seed Rate", "Candy Rate (MCH)")
      columns = seed_column_map(section)

      section.each do |row|
        next unless row[1].present? && numericish?(row[0])

        upsert_record(
          @bulletin.cotton_seed_rates,
          { particular: row[1] },
          position: integer_value(row[0]),
          madhya_pradesh_rate: row[columns[:madhya_pradesh_rate]],
          odisha_rate: row[columns[:odisha_rate]],
          maharashtra_rate: row[columns[:maharashtra_rate]],
          reference: row[columns[:reference]]
        )
      end
    end

    # The seed table repeats the same three states but not always in the same
    # order, so the header row decides which column feeds which attribute.
    def seed_column_map(section)
      defaults = { madhya_pradesh_rate: 2, odisha_rate: 3, maharashtra_rate: 4, reference: 6 }
      header = section.find { |row| row.any? { |cell| normalized(cell) == "particular" } }
      return defaults unless header

      map = {}
      header.each_with_index do |cell, index|
        key = case state_key(cell)
        when "mp" then :madhya_pradesh_rate
        when "mh" then :maharashtra_rate
        when "od" then :odisha_rate
        else normalized(cell)&.start_with?("reference") ? :reference : nil
        end
        map[key] ||= index if key
      end

      defaults.merge(map)
    end

    def import_candy_rows(rows, category, section_title)
      next_section = category == "mch" ? "Candy Rate (DCH)" : "Comparison Sheet"
      section = rows_between(rows, section_title, next_section)
      columns = candy_column_map(section)

      section.each do |row|
        next unless row[1].present? && numericish?(row[0])

        attributes = columns.each_with_object({}) do |(attribute, index), values|
          values[attribute] = row[index]
        end

        upsert_record(
          @bulletin.candy_rates,
          { category: category, parameter: row[1] },
          attributes.merge(
            position: integer_value(row[0]),
            category: category,
            parameter: row[1]
          )
        )
      end
    end

    # Candy tables carry a two-row header: the state on one row and the staple
    # length on the next ("MP" over "29 MM"). Reading both tells us which of the
    # six rate columns each spreadsheet column belongs to.
    def candy_column_map(section)
      header_index = section.index { |row| row.any? { |cell| normalized(cell) == "parameter" } }
      return { madhya_pradesh_rate: 2, maharashtra_29mm_rate: 3, maharashtra_31mm_rate: 4, odisha_29mm_rate: 5, odisha_30mm_rate: 6, reference: 7 } unless header_index

      state_row = section[header_index]
      length_row = section[header_index + 1].to_a
      length_row = [] if length_row.any? { |cell| numericish?(cell) }

      map = {}
      state_row.each_with_index do |cell, index|
        next if index < 2

        if normalized(cell)&.start_with?("reference")
          map[:reference] ||= index
          next
        end

        state = state_key(cell)
        next unless state

        attribute = candy_attribute(state, millimetre_value(length_row[index]))
        map[attribute] ||= index if attribute
      end

      map[:reference] ||= state_row.index { |cell| normalized(cell).to_s.start_with?("reference") }
      map.compact
    end

    def candy_attribute(state, millimetres)
      case state
      when "mp"
        millimetres && millimetres <= 29 ? :madhya_pradesh_29mm_rate : :madhya_pradesh_rate
      when "mh"
        millimetres && millimetres <= 29 ? :maharashtra_29mm_rate : :maharashtra_31mm_rate
      when "od"
        millimetres && millimetres <= 29 ? :odisha_29mm_rate : :odisha_30mm_rate
      end
    end

    # Re-importing a sheet the app itself exported can replay candy parameters
    # ("RD - 75", "DCH - 33-35 MM") inside the mandi table. They are rate
    # parameters, never mandis, so they never belong in a market section.
    def rate_parameter_name?(value)
      normalized(value).to_s.match?(/\A(rd|dch|mch)\s*[-\u2013]\s*\d/)
    end

    def state_key(value)
      text = normalized(value)
      return if text.blank?

      return "mp" if text.start_with?("mp") || text.include?("madhya")
      return "mh" if text.start_with?("mh") || text.include?("maharashtra")
      return "od" if text.start_with?("od") || text.include?("odisha") || text.include?("orissa")

      nil
    end

    def millimetre_value(value)
      normalized(value).to_s[/\d+/]&.to_i
    end

    def import_regional_rows(rows)
      price_index = rows.index { |row| row.any? { |cell| normalized(cell) == "price" } }
      return unless price_index

      rows[(price_index + 1)..].to_a.each_with_index do |row, offset|
        break if row.any? { |cell| normalized(cell).include?("total call") }
        next unless row[8].present?

        upsert_record(
          @bulletin.cotton_regional_comparisons,
          { line_item: row[8] },
          position: offset + 1,
          line_item: row[8],
          raipur_value: row[9],
          ojhar_value: row[10],
          kukshi_value: row[11],
          pati_value: row[12],
          sausar_value: row[13],
          jobat_value: row[14],
          odisha_value: row[15],
          extra_value_one: row[16],
          extra_value_two: row[17]
        )
      end
    end

    def import_call_rows(rows)
      header_index = rows.index { |row| row.any? { |cell| normalized(cell).include?("total call") } && row.any? { |cell| normalized(cell).include?("fully satisfied") } }
      return unless header_index

      rows[(header_index + 1)..].to_a.each_with_index do |row, offset|
        values = row[10, 6]
        next unless values&.first.present? && numericish?(values.first)

        upsert_record(
          @bulletin.cotton_call_performances,
          { position: offset + 1 },
          position: offset + 1,
          total_calls: integer_value(values[0]) || 0,
          fully_satisfied: integer_value(values[1]) || 0,
          satisfaction_percent: decimal_value(values[2]),
          call_again: integer_value(values[3]) || 0,
          wrong_call: integer_value(values[4]) || 0,
          invalid_exist: integer_value(values[5]) || 0
        )
      end
    end

    def import_comparison_rows(rows)
      rows_between(rows, "Comparison Sheet", nil).each do |row|
        next unless row[0].present? && row[1].present?

        position = @bulletin.cotton_market_observations.where(category: "comparison_sheet").count + 1
        record = @bulletin.cotton_market_observations.where(category: "comparison_sheet", observation_date: date_value(row[0])).first_or_initialize
        was_new = record.new_record?
        record.assign_attributes(
          position: record.position.presence || position,
          total_arrival: decimal_value(row[1]),
          traders_buy: decimal_value(row[2]),
          traders_percentage: decimal_value(row[3]),
          cci_buy: decimal_value(row[4]),
          cci_percentage: decimal_value(row[5]),
          buy_percentage: decimal_value(row[5]),
          remarks: row[6]
        )
        save_record(record, was_new)
      end
    end

    def upsert_observation(category, name, attrs)
      record = @bulletin.cotton_market_observations.where(category: category, name: name).first_or_initialize
      was_new = record.new_record?
      record.assign_attributes(attrs.merge(category: category, name: name))
      save_record(record, was_new)
    end

    def upsert_record(scope, keys, attrs)
      record = scope.where(keys).first_or_initialize
      was_new = record.new_record?
      record.assign_attributes(attrs)
      save_record(record, was_new)
    end

    def save_record(record, was_new)
      if record.save
        was_new ? @created += 1 : @updated += 1
      else
        @skipped += 1
        @errors << record.errors.full_messages.to_sentence
      end
    end

    def rows_between(rows, start_label, end_label)
      start_index = rows.index { |row| row.any? { |cell| normalized(cell).include?(normalized(start_label)) } }
      return [] unless start_index

      slice = rows[(start_index + 1)..].to_a
      end_index = end_label.present? ? slice.index { |row| row.any? { |cell| normalized(cell).include?(normalized(end_label)) } } : nil
      slice = slice.first(end_index) if end_index
      slice
    end

    def clean_value(value)
      value.to_s.gsub(/\u00a0/, " ").squish.presence
    end

    def normalized(value)
      clean_value(value).to_s.downcase
    end

    def numericish?(value)
      clean_value(value).to_s.match?(/\A\d+(\.\d+)?\z/)
    end

    def decimal_value(value)
      text = clean_value(value)
      return if text.blank? || text == "-"

      text.to_s.delete(",").match(/-?\d+(\.\d+)?/)&.[](0)&.to_d
    end

    def integer_value(value)
      decimal_value(value)&.to_i
    end

    def date_value(value)
      text = clean_value(value)
      return @bulletin.report_date if text.blank?
      return Date.strptime(text, "%d-%b-%y") if text.match?(/\A\d{1,2}-[A-Za-z]{3}-\d{2}\z/)
      Date.parse(text)
    rescue
      @bulletin.report_date
    end

    def result_with_error(message)
      Result.new(created: @created, updated: @updated, skipped: @skipped, errors: [ message ])
    end
end
