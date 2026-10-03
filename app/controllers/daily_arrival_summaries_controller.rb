class DailyArrivalSummariesController < ApplicationController
  include ReferenceCollections

  def index
    @states = state_options
    @filters = summary_filter_params.to_h.symbolize_keys
    @selected_state = State.find_by(id: @filters[:state_id]) if @filters[:state_id].present?

    @reports = filtered_reports
    @grouped_reports = @reports.group_by(&:district).sort_by { |district, _reports| district.name }
    @total_arrival_quantity = @reports.sum(&:arrival_quantity)
    @report_title = build_report_title
  end

  private
    def summary_filter_params
      params.permit(:state_id, :from_date, :to_date)
    end

    def filtered_reports
      scope = DailyPriceArrivalReport.recent_first
      scope = scope.where(state_id: @filters[:state_id]) if @filters[:state_id].present?
      scope = scope.where("arrival_date >= ?", @filters[:from_date]) if @filters[:from_date].present?
      scope = scope.where("arrival_date <= ?", @filters[:to_date]) if @filters[:to_date].present?
      scope.to_a
    end

    def build_report_title
      state_label = @selected_state&.name || "All States"
      start_date = Date.parse(@filters[:from_date]) if @filters[:from_date].present?
      end_date = Date.parse(@filters[:to_date]) if @filters[:to_date].present?
      period_label =
        if start_date && end_date
          "#{start_date.strftime("%d %b %Y")} – #{end_date.strftime("%d %b %Y")}"
        elsif start_date
          "From #{start_date.strftime("%d %b %Y")}"
        elsif end_date
          "Up to #{end_date.strftime("%d %b %Y")}"
        else
          "All available dates"
        end

      "#{state_label} · #{period_label}"
    end
end
