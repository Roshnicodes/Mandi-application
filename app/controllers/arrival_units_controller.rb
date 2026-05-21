class ArrivalUnitsController < ApplicationController
  before_action :set_arrival_unit, only: %i[edit update destroy]

  def index
    @arrival_units = ArrivalUnit.ordered
  end

  def new
    @arrival_unit = ArrivalUnit.new
  end

  def create
    @arrival_unit = ArrivalUnit.new(arrival_unit_params)

    if @arrival_unit.save
      redirect_to arrival_units_path, notice: "Arrival unit created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @arrival_unit.update(arrival_unit_params)
      redirect_to arrival_units_path, notice: "Arrival unit updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @arrival_unit.destroy
      redirect_to arrival_units_path, notice: "Arrival unit removed successfully."
    else
      redirect_to arrival_units_path, alert: @arrival_unit.errors.full_messages.to_sentence
    end
  end

  private
    def set_arrival_unit
      @arrival_unit = ArrivalUnit.find(params[:id])
    end

    def arrival_unit_params
      params.require(:arrival_unit).permit(:name, :short_name)
    end
end
