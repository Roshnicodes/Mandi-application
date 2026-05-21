class CottonMarketOverviewsController < ApplicationController
  def index
    @filters = overview_filter_params.to_h.symbolize_keys
    @titles = CottonBulletin.distinct.order(:title).pluck(:title)
    @bulletins = filtered_bulletins
    @grouped_bulletins = @bulletins.group_by(&:title)
  end

  private
    def overview_filter_params
      params.permit(:title, :from_date, :to_date)
    end

    def filtered_bulletins
      scope = CottonBulletin.includes(
        :cotton_market_observations,
        :cotton_seed_rates,
        :candy_rates,
        :cotton_regional_comparisons,
        :cotton_call_performances
      ).recent_first

      scope = scope.where(title: @filters[:title]) if @filters[:title].present?
      scope = scope.where("report_date >= ?", @filters[:from_date]) if @filters[:from_date].present?
      scope = scope.where("report_date <= ?", @filters[:to_date]) if @filters[:to_date].present?
      scope.to_a.sort_by(&:report_date)
    end
end
