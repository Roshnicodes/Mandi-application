class CottonBulletinsController < ApplicationController
  before_action :require_admin, except: %i[index show export comparison_sheet]
  before_action :set_cotton_bulletin, only: %i[show edit update destroy export comparison_sheet import]

  PER_PAGE = 15

  def index
    @latest_bulletin = CottonBulletin.recent_first.first
    @search = params[:q].to_s.strip
    @from_date = params[:from_date].presence
    @to_date = params[:to_date].presence
    @sort = params[:sort] == "date_asc" ? "date_asc" : "date_desc"
    scope = @sort == "date_asc" ? CottonBulletin.order(report_date: :asc, created_at: :asc) : CottonBulletin.recent_first
    if @search.present?
      term = "%#{@search}%"
      scope = scope.where(
        "title ILIKE :term OR to_char(report_date, 'DD Mon YYYY') ILIKE :term OR report_date::text ILIKE :term",
        term: term
      )
    end

    scope = scope.where("report_date >= ?", @from_date) if @from_date
    scope = scope.where("report_date <= ?", @to_date) if @to_date

    @per_page = PER_PAGE
    @saved_count = CottonBulletin.count
    @total_count = scope.count
    @total_pages = [ (@total_count.to_f / PER_PAGE).ceil, 1 ].max
    @page = params[:page].to_i
    @page = 1 if @page < 1
    @page = @total_pages if @page > @total_pages
    @cotton_bulletins = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
    preload_sections
  end

  def comparison_sheet
    @comparison_observations = @cotton_bulletin.observations_for("comparison_sheet")
  end

  def export
    prepare_export_sections

    if params[:preview].present?
      render :export, formats: :html, layout: false
    else
      file_name = [
        "daily-mandi-rate-cotton",
        @cotton_bulletin.report_date.strftime("%d-%m-%Y")
      ].join("-")

      send_data(
        render_to_string(:export, formats: :html, layout: false),
        filename: "#{file_name}.xls",
        type: "application/vnd.ms-excel; charset=utf-8",
        disposition: "attachment"
      )
    end
  end

  def import
    if params[:excel_file].blank?
      redirect_back fallback_location: cotton_bulletin_path(@cotton_bulletin), alert: "Please choose an Excel file to import."
      return
    end

    result = CottonBulletinExcelImporter.new(@cotton_bulletin, params[:excel_file]).import

    if result.success?
      redirect_back fallback_location: cotton_bulletin_path(@cotton_bulletin), notice: "Excel import complete: #{result.created} new, #{result.updated} updated rows."
    else
      redirect_back fallback_location: cotton_bulletin_path(@cotton_bulletin), alert: result.errors.to_sentence
    end
  end

  def start
    @cotton_bulletin = CottonBulletin.daily_for(direct_report_date)
    redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Daily cotton report is ready for #{@cotton_bulletin.report_date.strftime("%d %b %Y")}."
  rescue ArgumentError
    redirect_to cotton_bulletins_path, alert: "Choose a valid report date."
  end

  def import_daily
    if params[:excel_file].blank?
      redirect_to cotton_bulletins_path, alert: "Choose a cotton Excel file to import."
      return
    end

    result = CottonBulletinExcelImporter.import_workbook(params[:excel_file], fallback_date: direct_report_date)

    if result.errors.any?
      redirect_to cotton_bulletins_path, alert: result.errors.first(3).to_sentence
      return
    end

    if result.bulletins.empty?
      redirect_to cotton_bulletins_path, alert: "No dated sheets were found in this workbook."
      return
    end

    redirect_to import_target_path(result), notice: import_notice(result)
  rescue ArgumentError
    redirect_to cotton_bulletins_path, alert: "Choose a valid report date."
  end

  def new
    redirect_to cotton_bulletins_path, notice: "Choose a report date below to open a daily cotton entry."
  end

  def create
    @cotton_bulletin = CottonBulletin.new(cotton_bulletin_params)

    if @cotton_bulletin.save
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton bulletin created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cotton_bulletin.update(cotton_bulletin_params)
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton bulletin updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cotton_bulletin.destroy
    redirect_to cotton_bulletins_path, notice: "Cotton bulletin deleted successfully."
  end

  private
    def set_cotton_bulletin
      @cotton_bulletin = CottonBulletin.find(params[:id])
    end

    def preload_sections
      @mandi_observations = @cotton_bulletin.observations_for("mandi_wise")
      @gin_observations = @cotton_bulletin.observations_for("gin_wise")
      @cci_observations = @cotton_bulletin.observations_for("cci_mandi")
      @tdn_observations = @cotton_bulletin.observations_for("tdn_moisture")
      @comparison_observations = @cotton_bulletin.observations_for("comparison_sheet")
      @seed_rates = @cotton_bulletin.cotton_seed_rates.ordered
      @mch_rates = @cotton_bulletin.candy_rates_for("mch")
      @dch_rates = @cotton_bulletin.candy_rates_for("dch")
      @regional_comparisons = @cotton_bulletin.cotton_regional_comparisons.ordered
      @call_performances = @cotton_bulletin.cotton_call_performances.ordered
    end

    def prepare_export_sections
      @mandi_rows = market_export_rows("mandi_wise")
      @cci_rows = market_export_rows("cci_mandi")
      @gin_rows = @cotton_bulletin.cotton_market_observations.where(category: "gin_wise").ordered
      @tdn_rows = @cotton_bulletin.cotton_market_observations.where(category: "tdn_moisture").ordered
      @comparison_rows = @cotton_bulletin.cotton_market_observations.where(category: "comparison_sheet").ordered
      @seed_rows = @cotton_bulletin.cotton_seed_rates.ordered
      @mch_rows = @cotton_bulletin.candy_rates_for("mch")
      @dch_rows = @cotton_bulletin.candy_rates_for("dch")
    end

    def market_export_rows(category)
      rows_index = @cotton_bulletin.cotton_market_observations
        .where(category: category)
        .order(created_at: :desc, id: :desc)
        .group_by(&:name)
      template_rows = CottonMarketObservation.template_rows_for(category)
      template_names = template_rows.map { |row| row[:name] }
      ordered_names = template_names + (rows_index.keys - template_names).sort

      ordered_names.flat_map do |name|
        template_row = template_rows.find { |row| row[:name] == name } || {}

        Array(rows_index[name]).map do |record|
          {
            name: record.name,
            arrival_quantity: record.arrival_quantity,
            minimum_price: record.minimum_price,
            maximum_price: record.maximum_price,
            modal_price: record.modal_price,
            remarks: record.remarks.presence || template_row[:remarks],
            saved_at: record.created_at
          }
        end
      end
    end

    def cotton_bulletin_params
      permit_with_attachments(:cotton_bulletin, :report_date, :title, :notes)
    end

    # One workbook normally spans a month of sheets, so land on the index when
    # several dates were written and on the report itself when only one was.
    def import_target_path(result)
      result.bulletins.one? ? cotton_bulletin_path(result.bulletins.first) : cotton_bulletins_path
    end

    def import_notice(result)
      dates = "#{result.bulletins.size} #{"date".pluralize(result.bulletins.size)} (#{result.date_range_label})"
      summary = "Cotton Excel import complete for #{dates}: #{result.created} new, #{result.updated} updated rows."
      return summary if result.skipped_sheets.empty?

      "#{summary} #{result.skipped_sheets.size} hidden #{"sheet".pluralize(result.skipped_sheets.size)} skipped."
    end

    def direct_report_date
      return Date.current if params[:report_date].blank?

      Date.parse(params[:report_date])
    end
end
