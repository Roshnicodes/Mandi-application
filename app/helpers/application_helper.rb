module ApplicationHelper
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
    base = "Mandi Pro"
    title.present? ? "#{title} | #{base}" : base
  end

  def primary_navigation
    [
      {
        label: "Dashboard",
        path: root_path,
        active: controller_name == "dashboard"
      },
      {
        label: "Daily Reports",
        path: daily_price_arrival_reports_path,
        active: controller_name == "daily_price_arrival_reports"
      },
      {
        label: "Arrival Summary",
        path: daily_arrival_summaries_path,
        active: controller_name == "daily_arrival_summaries"
      },
      {
        label: "Cotton Bulletins",
        path: cotton_bulletins_path,
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
        active: controller_name == "cotton_market_overviews"
      }
    ]
  end

  def master_navigation
    [
      [ "State Master", states_path ],
      [ "District Master", districts_path ],
      [ "Market / APMC", markets_path ],
      [ "Commodity Group", commodity_groups_path ],
      [ "Commodity", commodities_path ],
      [ "Variety", varieties_path ],
      [ "Grade", grades_path ],
      [ "Price Unit", price_units_path ],
      [ "Arrival Unit", arrival_units_path ]
    ].map do |label, path|
      {
        label: label,
        path: path,
        active: current_page?(path)
      }
    end
  end

  def masters_section_active?
    MASTER_CONTROLLERS.include?(controller_name)
  end
end
