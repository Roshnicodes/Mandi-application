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
      start_label = @filters[:from_date].presence || "start"
      end_label = @filters[:to_date].presence || "today"
      state_label = @selected_state&.name || "All States"

      "Daily Price Arrival Report - #{start_label} to #{end_label} for #{state_label}"
    end
end
