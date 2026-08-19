class DashboardController < ApplicationController
  def index
    valid_reports = DailyPriceArrivalReport.includes(:state).recent_first.to_a.reject { |report| invalid_state_name?(report.state&.name) }

    @total_reports = valid_reports.size
    @recent_reports = valid_reports.first(8)
    @today_reports = valid_reports.count { |report| report.arrival_date == Date.current }
    @covered_mandis = valid_reports.map(&:market_id).uniq.size
    @latest_arrival_date = valid_reports.map(&:arrival_date).compact.max
    @latest_arrival_total = valid_reports
      .select { |report| report.arrival_date == @latest_arrival_date }
      .sum { |report| report.arrival_quantity.to_d }
    @dashboard_time = Time.zone.now
  end

  private
    def invalid_state_name?(name)
      normalized_name = name.to_s.squish.downcase
      normalized_name == "state" || normalized_name.start_with?("daily price arrival report")
    end
end
