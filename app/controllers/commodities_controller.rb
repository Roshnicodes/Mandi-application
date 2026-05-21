class CommoditiesController < ApplicationController
  include ReferenceCollections

  before_action :set_commodity, only: %i[edit update destroy]
  before_action :load_group_options, only: %i[new create edit update]

  def index
    @commodities = Commodity.includes(:commodity_group).ordered
  end

  def new
    @commodity = Commodity.new
  end

  def create
    @commodity = Commodity.new(commodity_params)

    if @commodity.save
      redirect_to commodities_path, notice: "Commodity created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @commodity.update(commodity_params)
      redirect_to commodities_path, notice: "Commodity updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @commodity.destroy
      redirect_to commodities_path, notice: "Commodity removed successfully."
    else
      redirect_to commodities_path, alert: @commodity.errors.full_messages.to_sentence
    end
  end

  private
    def set_commodity
      @commodity = Commodity.find(params[:id])
    end

    def load_group_options
      @commodity_groups = commodity_group_options
    end

    def commodity_params
      params.require(:commodity).permit(:commodity_group_id, :name, :organic)
    end
end
