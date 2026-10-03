class CottonMarketOverviewsController < ApplicationController
  def index
    @filters = overview_filter_params.to_h.symbolize_keys
    @titles = CottonBulletin.distinct.order(:title).pluck(:title)
    @bulletins = filtered_bulletins
    @grouped_bulletins = @bulletins.group_by(&:title)
  end

  private
    # Matches the report title or date, and the mandi and gin names recorded
    # inside it, so a user can pull up every sheet that mentions one mandi.
    def search_bulletins(scope, term)
      text = "%#{CottonBulletin.sanitize_sql_like(term.to_s.strip)}%"

      scope.where(
        "cotton_bulletins.title ILIKE :term
           OR to_char(cotton_bulletins.report_date, 'DD Mon YYYY') ILIKE :term
           OR cotton_bulletins.id IN (SELECT cotton_bulletin_id FROM cotton_market_observations WHERE name ILIKE :term)",
        term: text
      )
    end

    def overview_filter_params
      params.permit(:q, :title, :from_date, :to_date)
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
      scope = search_bulletins(scope, @filters[:q]) if @filters[:q].present?
      scope.to_a.sort_by(&:report_date)
    end
end
