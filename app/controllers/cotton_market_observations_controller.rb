class CottonMarketObservationsController < CottonBulletinNestedController
  before_action :set_cotton_market_observation, only: %i[edit update destroy]

  def new
    @cotton_market_observation = @cotton_bulletin.cotton_market_observations.new(category: params[:category])
  end

  def create
    @cotton_market_observation = @cotton_bulletin.cotton_market_observations.new(cotton_market_observation_params)

    if @cotton_market_observation.save
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton observation added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cotton_market_observation.update(cotton_market_observation_params)
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton observation updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cotton_market_observation.destroy
    redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton observation removed successfully."
  end

  private
    def set_cotton_market_observation
      @cotton_market_observation = @cotton_bulletin.cotton_market_observations.find(params[:id])
    end

    def cotton_market_observation_params
      params.require(:cotton_market_observation).permit(
        :category,
        :name,
        :observation_date,
        :arrival_quantity,
        :minimum_price,
        :maximum_price,
        :modal_price,
        :moisture,
        :arrival_price,
        :total_arrival,
        :traders_buy,
        :cci_buy,
        :buy_percentage,
        :traders_percentage,
        :cci_percentage,
        :remarks,
        :position
      )
    end
end
