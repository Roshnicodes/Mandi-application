class DistrictsController < ApplicationController
  include ReferenceCollections

  before_action :require_admin
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
      redirect_to after_quick_entry_create_path(@district), notice: "District created successfully."
    else
      if quick_entry_request?
        redirect_back fallback_location: new_daily_price_arrival_report_path(state_id: @district.state_id), alert: @district.errors.full_messages.to_sentence
        return
      end

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

    def quick_entry_request?
      params[:return_to_entry].present?
    end

    def after_quick_entry_create_path(district)
      return districts_path unless quick_entry_request?

      new_daily_price_arrival_report_path(state_id: district.state_id, district_id: district.id)
    end
end
