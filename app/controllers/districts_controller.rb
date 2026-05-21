class DistrictsController < ApplicationController
  include ReferenceCollections

  before_action :set_district, only: %i[edit update destroy]
  before_action :load_state_options, only: %i[new create edit update]

  def index
    @districts = District.includes(:state).ordered
  end

  def new
    @district = District.new
  end

  def create
    @district = District.new(district_params)

    if @district.save
      redirect_to districts_path, notice: "District created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @district.update(district_params)
      redirect_to districts_path, notice: "District updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @district.destroy
      redirect_to districts_path, notice: "District removed successfully."
    else
      redirect_to districts_path, alert: @district.errors.full_messages.to_sentence
    end
  end

  private
    def set_district
      @district = District.find(params[:id])
    end

    def load_state_options
      @states = state_options
    end

    def district_params
      params.require(:district).permit(:state_id, :name)
    end
end
