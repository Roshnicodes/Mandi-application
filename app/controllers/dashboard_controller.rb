class DashboardController < ApplicationController
  def index
    @latest_report_date = DailyPriceArrivalReport.maximum(:arrival_date)
    @total_reports = DailyPriceArrivalReport.count
    @markets_covered = DailyPriceArrivalReport.distinct.count(:market_id)
    @commodities_covered = DailyPriceArrivalReport.distinct.count(:commodity_id)
    @today_arrival_quantity = DailyPriceArrivalReport.where(arrival_date: @latest_report_date).sum(:arrival_quantity)
    @recent_reports = DailyPriceArrivalReport.recent_first.limit(8)
    @state_summaries = DailyPriceArrivalReport.joins(:state)
                                            .group("states.name")
                                            .order(Arel.sql("COUNT(daily_price_arrival_reports.id) DESC"))
                                            .limit(5)
                                            .count
  end
end
