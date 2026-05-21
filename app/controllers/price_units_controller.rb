class PriceUnitsController < ApplicationController
  before_action :set_price_unit, only: %i[edit update destroy]

  def index
    @price_units = PriceUnit.ordered
  end

  def new
    @price_unit = PriceUnit.new
  end

  def create
    @price_unit = PriceUnit.new(price_unit_params)

    if @price_unit.save
      redirect_to price_units_path, notice: "Price unit created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @price_unit.update(price_unit_params)
      redirect_to price_units_path, notice: "Price unit updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @price_unit.destroy
      redirect_to price_units_path, notice: "Price unit removed successfully."
    else
      redirect_to price_units_path, alert: @price_unit.errors.full_messages.to_sentence
    end
  end

  private
    def set_price_unit
      @price_unit = PriceUnit.find(params[:id])
    end

    def price_unit_params
      params.require(:price_unit).permit(:name, :short_name)
    end
end
