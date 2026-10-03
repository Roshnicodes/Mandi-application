class DashboardController < ApplicationController
  PER_PAGE_OPTIONS = [ 8, 15, 25, 50 ].freeze
  SORT_COLUMNS = %w[date mandi commodity variety grade modal arrival].freeze

  def index
    base_scope = valid_reports_scope

    @total_reports = base_scope.count
    @latest_arrival_date = base_scope.maximum(:arrival_date)
    @latest_arrival_total = @latest_arrival_date ? base_scope.where(arrival_date: @latest_arrival_date).sum(:arrival_quantity) : 0
    @today_reports = base_scope.where(arrival_date: Date.current).count
    @covered_mandis = base_scope.distinct.count(:market_id)
    @dashboard_time = Time.zone.now

    @filter_date = parse_date(params[:date])
    @dashboard_report_date = @filter_date || @latest_arrival_date || Date.current
    prepare_dashboard_insights(base_scope)

    scope = base_scope.includes(:market, :district, :state, :commodity, :variety, :grade)
    scope = scope.where(arrival_date: @filter_date) if @filter_date

    @search = params[:q].to_s.strip
    if @search.present?
      term = "%#{@search}%"
      scope = scope.joins(:market, :district, :variety)
        .where("markets.name ILIKE :t OR districts.name ILIKE :t OR varieties.name ILIKE :t", t: term)
    end

    @sort_column = SORT_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : "date"
    @sort_dir = params[:sort_dir] == "asc" ? "asc" : "desc"
    scope = apply_sort(scope, @sort_column, @sort_dir)

    @per_page = params[:per_page].to_i
    @per_page = 8 unless PER_PAGE_OPTIONS.include?(@per_page)

    @total_count = scope.count
    @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages
    @recent_reports = scope.offset((@page - 1) * @per_page).limit(@per_page)
  end

  private
    def prepare_dashboard_insights(base_scope)
      trend_start = @dashboard_report_date - 6.days
      daily_totals = base_scope
        .where(arrival_date: trend_start..@dashboard_report_date)
        .group(:arrival_date)
        .sum(:arrival_quantity)

      @arrival_trend = (trend_start..@dashboard_report_date).map do |date|
        { date: date, quantity: daily_totals.fetch(date, 0).to_f }
      end
      @arrival_trend_peak = @arrival_trend.map { |entry| entry[:quantity] }.max.to_f

      report_day_scope = base_scope.where(arrival_date: @dashboard_report_date)
      commodity_totals = report_day_scope
        .joins(:commodity)
        .group("commodities.name")
        .sum(:arrival_quantity)
        .sort_by { |name, quantity| [ -quantity.to_f, name.to_s ] }
      prepare_commodity_share(commodity_totals)

      @top_markets = report_day_scope
        .joins(:market)
        .group("markets.name")
        .sum(:arrival_quantity)
        .sort_by { |name, quantity| [ -quantity.to_f, name.to_s ] }
        .first(5)
        .map { |name, quantity| { name: name, quantity: quantity.to_f } }
      @top_market_peak = @top_markets.map { |market| market[:quantity] }.max.to_f
    end

    def prepare_commodity_share(commodity_totals)
      total_quantity = commodity_totals.sum { |_, quantity| quantity.to_f }
      @dashboard_arrival_total = total_quantity
      top_commodities = commodity_totals.first(4)
      remaining_quantity = commodity_totals.drop(4).sum { |_, quantity| quantity.to_f }
      top_commodities << [ "Other", remaining_quantity ] if remaining_quantity.positive?

      colors = %w[#2563eb #22c55e #f59e0b #8b5cf6 #ec4899]
      @commodity_shares = top_commodities.each_with_index.map do |(name, quantity), index|
        {
          name: name,
          quantity: quantity.to_f,
          percent: total_quantity.positive? ? ((quantity.to_f / total_quantity) * 100).round : 0,
          color: colors[index]
        }
      end

      cursor = 0.0
      @commodity_share_gradient = @commodity_shares.map do |share|
        from = cursor
        cursor += share[:percent]
        "#{share[:color]} #{from.round(2)}% #{cursor.round(2)}%"
      end.join(", ")
    end

    def valid_reports_scope
      DailyPriceArrivalReport
        .joins(:state)
        .where.not("LOWER(states.name) = :a OR LOWER(states.name) LIKE :b", a: "state", b: "daily price arrival report%")
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError
      nil
    end

    def apply_sort(scope, column, dir)
      direction = dir == "asc" ? "ASC" : "DESC"
      case column
      when "mandi"
        scope.joins(:market).reorder("markets.name #{direction}")
      when "commodity"
        scope.joins(:commodity).reorder("commodities.name #{direction}")
      when "variety"
        scope.joins(:variety).reorder("varieties.name #{direction}")
      when "grade"
        scope.joins(:grade).reorder("grades.name #{direction}")
      when "modal"
        scope.reorder("daily_price_arrival_reports.modal_price #{direction}")
      when "arrival"
        scope.reorder("daily_price_arrival_reports.arrival_quantity #{direction}")
      else
        scope.reorder("daily_price_arrival_reports.arrival_date #{direction}, daily_price_arrival_reports.created_at #{direction}")
      end
    end
end
