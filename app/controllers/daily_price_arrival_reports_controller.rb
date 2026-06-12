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

  def export
    @filters = filter_params.to_h.symbolize_keys
    @reports = DailyPriceArrivalReport.filtered(@filters)

    if params[:preview].present?
      render :export, formats: :html, layout: false
    else
      send_data(
        render_to_string(:export, formats: :html, layout: false),
        filename: "daily-price-arrival-reports-#{Date.current.strftime("%d-%m-%Y")}.xls",
        type: "application/vnd.ms-excel; charset=utf-8",
        disposition: "attachment"
      )
    end
  end

  def import
    if params[:excel_file].blank?
      redirect_back fallback_location: daily_price_arrival_reports_path, alert: "Import ke liye Excel file choose kariye."
      return
    end

    result = DailyPriceArrivalReportExcelImporter.new(params[:excel_file]).import

    if result.success?
      redirect_back fallback_location: daily_price_arrival_reports_path, notice: "Daily Excel import complete: #{result.created} new, #{result.updated} updated, #{result.skipped} skipped."
    else
      redirect_back fallback_location: daily_price_arrival_reports_path, alert: result.errors.to_sentence
    end
  end

  def new
    @daily_price_arrival_report = DailyPriceArrivalReport.new(entry_report_defaults)
    prepare_report_entry_grid
  end

  def create
    @daily_price_arrival_report = DailyPriceArrivalReport.new(daily_price_arrival_report_params)

    if @daily_price_arrival_report.save
      redirect_to new_daily_price_arrival_report_path(
        state_id: @daily_price_arrival_report.state_id,
        district_id: @daily_price_arrival_report.district_id,
        market_id: @daily_price_arrival_report.market_id,
        commodity_group_id: @daily_price_arrival_report.commodity_group_id,
        commodity_id: @daily_price_arrival_report.commodity_id,
        variety_id: @daily_price_arrival_report.variety_id,
        grade_id: @daily_price_arrival_report.grade_id,
        price_unit_id: @daily_price_arrival_report.price_unit_id,
        arrival_unit_id: @daily_price_arrival_report.arrival_unit_id
      ), notice: "Daily report saved successfully."
    else
      prepare_report_entry_grid
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @daily_price_arrival_report.update(daily_price_arrival_report_params)
      redirect_to after_change_redirect_path(@daily_price_arrival_report), notice: "Daily report updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    redirect_path = after_change_redirect_path(@daily_price_arrival_report)
    @daily_price_arrival_report.destroy
    redirect_to redirect_path, notice: "Daily report deleted successfully."
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

    def prepare_report_entry_grid
      @entry_states = State.includes(districts: :markets).ordered.select { |state| state.districts.any? { |district| district.markets.any? } }
      @selected_state = State.find_by(id: params[:state_id]) || @daily_price_arrival_report.state || @entry_states.first
      @entry_districts = @selected_state&.districts&.includes(:markets)&.ordered&.select { |district| district.markets.any? } || []
      @selected_district = District.find_by(id: params[:district_id]) || @daily_price_arrival_report.district
      @entry_markets =
        if @selected_district.present?
          Market.includes(district: :state).where(district: @selected_district).ordered
        elsif @selected_state.present?
          Market.includes(district: :state).joins(:district).where(districts: { state_id: @selected_state.id }).order("districts.name ASC", "markets.name ASC")
        else
          Market.none
        end
      @active_market_id = params[:market_id].presence || @daily_price_arrival_report.market_id
      @entry_arrival_date = @daily_price_arrival_report.arrival_date || Date.current

      market_ids = @entry_markets.map(&:id)
      reports = DailyPriceArrivalReport
        .recent_first
        .where(market_id: market_ids)
        .where(arrival_date: @entry_arrival_date)
      reports = reports.where(commodity_id: @daily_price_arrival_report.commodity_id) if @daily_price_arrival_report.commodity_id.present?
      reports = reports.where(variety_id: @daily_price_arrival_report.variety_id) if @daily_price_arrival_report.variety_id.present?

      @reports_by_market = reports.group_by(&:market_id)
    end

    def entry_report_defaults
      defaults = DailyPriceArrivalReport.default_entry_attributes

      {
        arrival_date: defaults[:arrival_date],
        commodity_group: CommodityGroup.find_by(id: params[:commodity_group_id]) || defaults[:commodity_group],
        commodity: Commodity.find_by(id: params[:commodity_id]) || defaults[:commodity],
        variety: Variety.find_by(id: params[:variety_id]) || defaults[:variety],
        grade: Grade.find_by(id: params[:grade_id]) || defaults[:grade],
        price_unit: PriceUnit.find_by(id: params[:price_unit_id]) || defaults[:price_unit],
        arrival_unit: ArrivalUnit.find_by(id: params[:arrival_unit_id]) || defaults[:arrival_unit]
      }.compact
    end

    def filter_params
      params.permit(:state_id, :district_id, :market_id, :commodity_group_id, :commodity_id, :variety_id, :from_date, :to_date)
    end

    def after_change_redirect_path(report)
      return daily_price_arrival_reports_path unless params[:return_to_entry].present?

      new_daily_price_arrival_report_path(
        state_id: params[:state_id].presence || report.state_id,
        district_id: params[:district_id].presence,
        market_id: params[:market_id].presence || report.market_id,
        commodity_group_id: params[:commodity_group_id].presence || report.commodity_group_id,
        commodity_id: params[:commodity_id].presence || report.commodity_id,
        variety_id: params[:variety_id].presence || report.variety_id,
        grade_id: params[:grade_id].presence || report.grade_id,
        price_unit_id: params[:price_unit_id].presence || report.price_unit_id,
        arrival_unit_id: params[:arrival_unit_id].presence || report.arrival_unit_id
      )
    end

    def daily_price_arrival_report_params
      permit_with_attachments(
        :daily_price_arrival_report,
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
