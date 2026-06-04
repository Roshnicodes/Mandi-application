class CottonBulletinsController < ApplicationController
  before_action :set_cotton_bulletin, only: %i[show edit update destroy export import]

  def index
    @cotton_bulletins = CottonBulletin.recent_first
  end

  def show
    preload_sections
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
      redirect_back fallback_location: cotton_bulletin_path(@cotton_bulletin), alert: "Import ke liye Excel file choose kariye."
      return
    end

    result = CottonBulletinExcelImporter.new(@cotton_bulletin, params[:excel_file]).import

    if result.success?
      redirect_back fallback_location: cotton_bulletin_path(@cotton_bulletin), notice: "Excel import complete: #{result.created} new, #{result.updated} updated rows."
    else
      redirect_back fallback_location: cotton_bulletin_path(@cotton_bulletin), alert: result.errors.to_sentence
    end
  end

  def new
    @cotton_bulletin = CottonBulletin.new
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
      @regional_rows = @cotton_bulletin.cotton_regional_comparisons.ordered
      @call_rows = @cotton_bulletin.cotton_call_performances.ordered
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
end
