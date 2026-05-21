class CottonBulletinsController < ApplicationController
  before_action :set_cotton_bulletin, only: %i[show edit update destroy]

  def index
    @cotton_bulletins = CottonBulletin.recent_first
  end

  def show
    preload_sections
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

    def cotton_bulletin_params
      params.require(:cotton_bulletin).permit(:report_date, :title, :notes)
    end
end
