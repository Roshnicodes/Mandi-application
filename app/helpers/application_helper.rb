module ApplicationHelper
  FEATURED_MANDI_NAMES = %w[
    Jobat
    Kukshi
    Petlawad
    Anjad
    Sausar
    Ratlam
    Chhindwara
    Betul
    Raoti
    Mandla
    Anjaniya
    Dindori
  ].freeze

  MASTER_CONTROLLERS = %w[
    states
    districts
    markets
    commodity_groups
    commodities
    varieties
    grades
    price_units
    arrival_units
  ].freeze

  ICONS = {
    "home" => '<path d="M3 10.5 12 3l9 7.5"/><path d="M5.5 9.5V20a1 1 0 0 0 1 1H9.5a1 1 0 0 0 1-1v-4a1 1 0 0 1 1-1h1a1 1 0 0 1 1 1v4a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1V9.5"/>',
    "document" => '<path d="M7 3h7l5 5v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"/><path d="M14 3v5h5"/><path d="M9 13h6M9 17h6M9 9h2"/>',
    "chart-bar" => '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    "shield" => '<path d="M12 3 4.5 6v6c0 4.5 3.2 7.6 7.5 9 4.3-1.4 7.5-4.5 7.5-9V6L12 3Z"/>',
    "map-pin" => '<circle cx="12" cy="10.5" r="3"/><path d="M12 21.5c4-4 7-7.3 7-11a7 7 0 1 0-14 0c0 3.7 3 7 7 11Z"/>',
    "building" => '<rect x="4" y="3" width="16" height="18" rx="1"/><path d="M8 7h.01M12 7h.01M16 7h.01M8 11h.01M12 11h.01M16 11h.01M8 15h.01M12 15h.01M16 15h.01M10 21v-4h4v4"/>',
    "folder" => '<path d="M3 7a1 1 0 0 1 1-1h4.5l2 2H20a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V7Z"/>',
    "leaf" => '<path d="M20 4c0 9-5.5 13-11 13a5.5 5.5 0 0 1-5.5-5.5C3.5 7 9 4 20 4Z"/><path d="M4 20c2.5-5 6-8 11-10"/>',
    "package" => '<path d="m3.5 7.5 8.5-4 8.5 4-8.5 4-8.5-4Z"/><path d="M3.5 7.5v9l8.5 4 8.5-4v-9"/><path d="M12 11.5v9"/>',
    "tag" => '<path d="M11.5 3H5a1 1 0 0 0-1 1v6.5a1 1 0 0 0 .3.7l9 9a1 1 0 0 0 1.4 0l6.5-6.5a1 1 0 0 0 0-1.4l-9-9a1 1 0 0 0-.7-.3Z"/><circle cx="8" cy="8" r="1.3"/>',
    "badge" => '<circle cx="12" cy="12" r="9"/><path d="m9 12 2 2 4-4"/>',
    "calendar" => '<rect x="3.5" y="5" width="17" height="16" rx="1.5"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/>',
    "spreadsheet" => '<rect x="3.5" y="3.5" width="17" height="17" rx="1.5"/><path d="M3.5 9h17M3.5 14.5h17M9.5 3.5v17"/>',
    "search" => '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m20 20-4.3-4.3"/>',
    "download" => '<path d="M12 3v12m0 0 4-4m-4 4-4-4"/><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/>',
    "eye" => '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="3"/>',
    "folder-open" => '<path d="M3 8a1 1 0 0 1 1-1h4.5l2 2H19a1 1 0 0 1 1 .8l-1.4 7.8a1 1 0 0 1-1 .8H5.3a1 1 0 0 1-1-.8L3 9.5Z"/>',
    "pencil" => '<path d="M14.5 4.5 19.5 9.5 8 21H3v-5Z"/><path d="m12.5 6.5 5 5"/>',
    "trash" => '<path d="M4 7h16M9 7V4.5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1V7M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13"/>',
    "upload" => '<path d="M12 15V3m0 0 4 4m-4-4-4 4"/><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/>',
    "chevron-left" => '<path d="m14.5 5-7 7 7 7"/>',
    "chevron-right" => '<path d="m9.5 5 7 7-7 7"/>',
    "sort" => '<path d="m7 9 3-4 3 4M7 15l3 4 3-4"/>',
    "plus" => '<path d="M12 5v14M5 12h14"/>',
    "logout" => '<path d="M9 21H5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h4"/><path d="M16 17l5-5-5-5M21 12H9"/>',
    "truck" => '<rect x="1.5" y="7" width="13" height="10" rx="1"/><path d="M14.5 10.5H18l3.5 3.5V17a1 1 0 0 1-1 1h-1.5"/><circle cx="6" cy="18.5" r="1.6"/><circle cx="17.5" cy="18.5" r="1.6"/>',
    "sliders" => '<path d="M4 6h10M17 6h3M4 12h3M9 12h11M4 18h7M14 18h6"/><circle cx="16" cy="6" r="2"/><circle cx="7" cy="12" r="2"/><circle cx="12" cy="18" r="2"/>',
    "chevron-down" => '<path d="m5 8.5 7 7 7-7"/>'
  }.freeze

  def icon(name, size: 18, class_name: nil)
    body = ICONS[name.to_s]
    return "" unless body

    classes = [ "icon", class_name ].compact.join(" ")
    raw(
      %(<svg class="#{classes}" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{body}</svg>)
    )
  end

  def flash_class(type)
    case type.to_sym
    when :alert
      "flash flash-alert"
    when :notice
      "flash flash-notice"
    else
      "flash"
    end
  end

  def app_title(title = nil)
    base = "IMAN"
    title.present? ? "#{title} | #{base}" : base
  end

  def primary_navigation
    [
      {
        label: "Dashboard",
        path: root_path,
        icon: "home",
        active: controller_name == "dashboard"
      },
      {
        label: "Daily Reports",
        path: daily_price_arrival_reports_path,
        icon: "document",
        active: controller_name == "daily_price_arrival_reports"
      },
      {
        label: "Arrival Summary",
        path: daily_arrival_summaries_path,
        icon: "document",
        active: controller_name == "daily_arrival_summaries"
      },
      {
        label: "Cotton Bulletins",
        path: cotton_bulletins_path,
        icon: "document",
        active: %w[
          cotton_bulletins
          cotton_market_observations
          cotton_seed_rates
          candy_rates
          cotton_regional_comparisons
          cotton_call_performances
        ].include?(controller_name)
      },
      {
        label: "Cotton Overview",
        path: cotton_market_overviews_path,
        icon: "chart-bar",
        active: controller_name == "cotton_market_overviews"
      }
    ]
  end

  def master_navigation
    return [] unless admin_user?

    [
      [ "State Master", states_path, "shield" ],
      [ "District Master", districts_path, "map-pin" ],
      [ "Mandi / APMC", markets_path, "building" ],
      [ "Commodity Group", commodity_groups_path, "folder" ],
      [ "Commodity", commodities_path, "package" ],
      [ "Variety", varieties_path, "tag" ],
      [ "Grade", grades_path, "badge" ],
      [ "Price Unit", price_units_path, "tag" ],
      [ "Arrival Unit", arrival_units_path, "tag" ]
    ].map do |label, path, icon_name|
      {
        label: label,
        path: path,
        icon: icon_name,
        active: current_page?(path)
      }
    end
  end

  def masters_section_active?
    admin_user? && MASTER_CONTROLLERS.include?(controller_name)
  end

  def featured_mandi_names
    FEATURED_MANDI_NAMES
  end

  def pagination_window(current, total)
    return (1..total).to_a if total <= 7

    if current <= 4
      [ *1..5, :gap, total ]
    elsif current >= total - 3
      [ 1, :gap, *(total - 4)..total ]
    else
      [ 1, :gap, *(current - 1)..(current + 1), :gap, total ]
    end
  end

  # State masters are keyed by their short code, so the sheet header spells the
  # name out and keeps the code in brackets when we recognise the abbreviation.
  STATE_FULL_NAMES = {
    "mp" => "Madhya Pradesh",
    "mh" => "Maharashtra",
    "gj" => "Gujarat",
    "rj" => "Rajasthan",
    "up" => "Uttar Pradesh",
    "cg" => "Chhattisgarh",
    "pb" => "Punjab",
    "hr" => "Haryana",
    "ka" => "Karnataka",
    "ts" => "Telangana",
    "ap" => "Andhra Pradesh",
    "tn" => "Tamil Nadu",
    "od" => "Odisha",
    "wb" => "West Bengal",
    "br" => "Bihar"
  }.freeze

  def state_display_name(state)
    name = state.name.to_s
    full_name = STATE_FULL_NAMES[name.downcase]
    return name if full_name.blank?

    "#{full_name} (#{name})"
  end

  # Orders the rows inside one daily sheet card by the column the user picked.
  def sorted_daily_reports(reports, column, direction)
    sorter = DailyPriceArrivalReportsController::SORT_COLUMNS.fetch(column) { |_| nil }
    return reports.sort_by { |report| report.market.name.to_s.downcase } unless sorter

    sorted = reports.sort_by { |report| [ sorter.call(report), report.market.name.to_s.downcase ] }
    direction == "desc" ? sorted.reverse : sorted
  end

  def mandi_display_name(name)
    name
      .to_s
      .squish
      .sub(/\s+APMC\z/i, "")
      .sub(/\s*\(Bamnia\)/i, "")
      .sub(/\s*-\s*DCH\z/i, "")
  end
end
