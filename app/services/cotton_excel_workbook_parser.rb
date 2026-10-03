require "nokogiri"
require "zip"

# Reads a cotton workbook and returns every worksheet it holds, in workbook
# order, together with the report date each sheet stands for.
#
# The daily cotton workbook keeps one sheet per reporting day and names the tab
# after that day ("29.09.2026"), so a single upload normally carries a whole
# month of reports.
class CottonExcelWorkbookParser
  Sheet = Data.define(:name, :rows, :hidden, :report_date) do
    def blank?
      rows.blank?
    end
  end

  MONTH_NAMES = Date::ABBR_MONTHNAMES.compact.map(&:downcase).freeze

  def initialize(upload)
    @upload = upload
  end

  def sheets
    @sheets ||= parse.reject(&:blank?)
  end

  # Sheets the user is meant to import: visible tabs that resolve to a date.
  def dated_sheets
    sheets.reject(&:hidden).select(&:report_date)
  end

  def path
    @path ||= @upload.respond_to?(:path) ? @upload.path : @upload.tempfile.path
  end

  private
    def parse
      if xlsx?
        parse_xlsx
      else
        [ Sheet.new(name: nil, rows: parse_html_table, hidden: false, report_date: nil) ]
      end
    ensure
      @upload&.tempfile&.rewind if @upload&.respond_to?(:tempfile)
    end

    def xlsx?
      original_name = @upload.respond_to?(:original_filename) ? @upload.original_filename.to_s : path
      File.extname(original_name).downcase == ".xlsx" || zip_file?
    end

    def zip_file?
      File.binread(path, 4) == "PK\x03\x04"
    rescue
      false
    end

    def parse_html_table
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

    def parse_xlsx
      Zip::File.open(path) do |zip|
        shared_strings = shared_strings(zip)

        sheet_entries(zip).map do |entry|
          rows = sheet_rows(zip, entry[:target], shared_strings)

          Sheet.new(
            name: entry[:name],
            rows: rows,
            hidden: entry[:hidden],
            report_date: date_from_sheet_name(entry[:name]) || date_from_rows(rows)
          )
        end
      end
    end

    # Worksheets are listed in workbook.xml in tab order; the file each tab
    # points at only comes from the relationship ids, never from the file name.
    def sheet_entries(zip)
      workbook = zip.find_entry("xl/workbook.xml")
      return fallback_sheet_entries(zip) unless workbook

      document = Nokogiri::XML(workbook.get_input_stream.read)
      document.remove_namespaces!
      relationships = sheet_relationships(zip)

      entries = document.css("sheets sheet").filter_map do |node|
        target = relationships[node["id"].to_s]
        next unless target

        {
          name: clean_value(node["name"]),
          target: target,
          hidden: node["state"].to_s.downcase.in?(%w[hidden veryhidden])
        }
      end

      entries.presence || fallback_sheet_entries(zip)
    end

    def fallback_sheet_entries(zip)
      zip.glob("xl/worksheets/sheet*.xml").sort_by { |entry| entry.name[/\d+/].to_i }.map do |entry|
        { name: nil, target: entry.name, hidden: false }
      end
    end

    def sheet_relationships(zip)
      entry = zip.find_entry("xl/_rels/workbook.xml.rels")
      return {} unless entry

      document = Nokogiri::XML(entry.get_input_stream.read)
      document.remove_namespaces!

      document.css("Relationship").each_with_object({}) do |node, map|
        target = node["Target"].to_s
        next unless target.include?("worksheets/")

        map[node["Id"].to_s] = target.start_with?("/") ? target.sub(%r{\A/}, "") : "xl/#{target.sub(%r{\A\./}, "")}"
      end
    end

    def sheet_rows(zip, target, shared_strings)
      entry = zip.find_entry(target)
      return [] unless entry

      sheet = Nokogiri::XML(entry.get_input_stream.read)
      sheet.remove_namespaces!

      sheet.css("row").map do |row|
        cells = []
        row.css("c").each do |cell|
          index = column_index(cell["r"].to_s[/[A-Z]+/])
          next if index.negative?

          cells[index] = cell_value(cell, shared_strings)
        end
        cells
      end
    end

    def shared_strings(zip)
      entry = zip.find_entry("xl/sharedStrings.xml")
      return [] unless entry

      xml = Nokogiri::XML(entry.get_input_stream.read)
      xml.remove_namespaces!
      xml.css("si").map { |node| clean_value(node.css("t").map(&:text).join) }
    end

    def cell_value(cell, shared_strings)
      value = cell.at_css("v")&.text
      return clean_value(cell.at_css("is t")&.text) if value.blank?
      return shared_strings[value.to_i] if cell["t"] == "s"

      clean_value(value)
    end

    def column_index(letters)
      letters.to_s.chars.reduce(0) { |sum, char| (sum * 26) + char.ord - 64 } - 1
    end

    # Tab names look like "29.09.2026", sometimes with a stray trailing dot or a
    # suffix such as "29.09.2026 (final)".
    def date_from_sheet_name(name)
      text = clean_value(name)
      return if text.blank?

      match = text.match(/(\d{1,2})[.\-\/_](\d{1,2})[.\-\/_](\d{2,4})/)
      return unless match

      day, month, year = match.captures.map(&:to_i)
      year += year < 70 ? 2000 : 1900 if year < 100

      Date.new(year, month, day)
    rescue Date::Error
      nil
    end

    # Falls back to the banner the sheet prints in its first rows, e.g.
    # "29th Sep - 2026".
    def date_from_rows(rows)
      rows.first(6).each do |row|
        Array(row).each do |cell|
          date = date_from_label(cell)
          return date if date
        end
      end

      nil
    end

    def date_from_label(value)
      text = clean_value(value)
      return if text.blank?

      match = text.match(/(\d{1,2})\s*(?:st|nd|rd|th)?\s*[-\/ ]\s*([A-Za-z]{3,})[-\/ ,]*\s*(\d{2,4})/)
      return unless match

      day = match[1].to_i
      month = MONTH_NAMES.index(match[2].downcase.first(3))
      return unless month

      year = match[3].to_i
      year += year < 70 ? 2000 : 1900 if year < 100

      Date.new(year, month + 1, day)
    rescue Date::Error
      nil
    end

    def clean_value(value)
      value.to_s.gsub(/ /, " ").squish.presence
    end
end
