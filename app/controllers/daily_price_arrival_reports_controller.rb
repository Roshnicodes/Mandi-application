class DailyPriceArrivalReportsController < ApplicationController
  include ReferenceCollections

  before_action :set_daily_price_arrival_report, only: %i[edit update destroy]
  before_action :load_report_form_collections, only: %i[new create edit update]
  before_action :load_filter_collections, only: :index

  def index
    @filters = filter_params.to_h.symbolize_keys
    @reports = DailyPriceArrivalReport.filtered(@filters)
    @filtered_arrival_total = @reports.unscope(:order).sum(:arrival_quantity)
    @filtered_count = @reports.count
  end

  def new
    @daily_price_arrival_report = DailyPriceArrivalReport.new
  end

  def create
    @daily_price_arrival_report = DailyPriceArrivalReport.new(daily_price_arrival_report_params)

    if @daily_price_arrival_report.save
      redirect_to daily_price_arrival_reports_path, notice: "Daily report saved successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @daily_price_arrival_report.update(daily_price_arrival_report_params)
      redirect_to daily_price_arrival_reports_path, notice: "Daily report updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @daily_price_arrival_report.destroy
    redirect_to daily_price_arrival_reports_path, notice: "Daily report deleted successfully."
  end

  private
    def set_daily_price_arrival_report
      @daily_price_arrival_report = DailyPriceArrivalReport.find(params[:id])
    end

    def load_report_form_collections
      @states = state_options
      @districts_data = districts_payload
      @markets_data = markets_payload
      @commodity_groups = commodity_group_options
      @commodities_data = commodities_payload
      @varieties_data = varieties_payload
      @grades_data = grades_payload
      @price_units = price_unit_options
      @arrival_units = arrival_unit_options
    end

    def load_filter_collections
      @states = state_options
      @districts = district_options
      @markets = market_options
      @commodity_groups = commodity_group_options
      @commodities = commodity_options
      @varieties = variety_options
    end

    def filter_params
      params.permit(:state_id, :district_id, :market_id, :commodity_group_id, :commodity_id, :variety_id, :from_date, :to_date)
    end

    def daily_price_arrival_report_params
      params.require(:daily_price_arrival_report).permit(
        :state_id,
        :district_id,
        :market_id,
        :commodity_group_id,
        :commodity_id,
        :variety_id,
        :grade_id,
        :price_unit_id,
        :arrival_unit_id,
        :arrival_date,
        :min_price,
        :max_price,
        :modal_price,
        :arrival_quantity,
        :remarks
      )
    end
end
