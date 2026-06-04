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

  def initialize(bulletin, upload)
    @bulletin = bulletin
    @upload = upload
    @created = 0
    @updated = 0
    @skipped = 0
    @errors = []
  end

  def import
    rows = parse_rows
    return result_with_error("Excel file me readable rows nahi mili.") if rows.blank?

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
    result_with_error("XLSX file open nahi ho payi. File corrupt ya unsupported format me ho sakti hai.")
  rescue => error
    Rails.logger.error("Cotton bulletin import failed: #{error.class}: #{error.message}")
    result_with_error("Import nahi ho paya: #{error.message}")
  ensure
    @upload&.tempfile&.rewind if @upload&.respond_to?(:tempfile)
  end

  private
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

    def import_market_rows(rows)
      left_rows = rows_between(rows, "Mandi Wise", "Cotton Seed Rate")
      left_rows.each do |row|
        next unless row[1].present? && numericish?(row[0])

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
      rows_between(rows, "Cotton Seed Rate", "Candy Rate (MCH)").each do |row|
        next unless row[1].present? && numericish?(row[0])

        upsert_record(
          @bulletin.cotton_seed_rates,
          { particular: row[1] },
          position: integer_value(row[0]),
          madhya_pradesh_rate: row[2],
          odisha_rate: row[3],
          maharashtra_rate: row[4],
          reference: row[6]
        )
      end
    end

    def import_candy_rows(rows, category, section_title)
      next_section = category == "mch" ? "Candy Rate (DCH)" : "Comparison Sheet"

      rows_between(rows, section_title, next_section).each do |row|
        next unless row[1].present? && numericish?(row[0])

        upsert_record(
          @bulletin.candy_rates,
          { category: category, parameter: row[1] },
          position: integer_value(row[0]),
          category: category,
          parameter: row[1],
          madhya_pradesh_rate: row[2],
          maharashtra_29mm_rate: row[3],
          maharashtra_31mm_rate: row[4],
          odisha_29mm_rate: row[5],
          odisha_30mm_rate: row[6]
        )
      end
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
      return Date.parse(text)
    rescue
      @bulletin.report_date
    end

    def result_with_error(message)
      Result.new(created: @created, updated: @updated, skipped: @skipped, errors: [ message ])
    end
end
