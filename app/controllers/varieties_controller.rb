class VarietiesController < ApplicationController
  include ReferenceCollections

  before_action :set_variety, only: %i[edit update destroy]
  before_action :load_commodity_options, only: %i[new create edit update]

  def index
    @varieties = Variety.includes(commodity: :commodity_group).ordered
  end

  def new
    @variety = Variety.new
  end

  def create
    @variety = Variety.new(variety_params)

    if @variety.save
      redirect_to varieties_path, notice: "Variety created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @variety.update(variety_params)
      redirect_to varieties_path, notice: "Variety updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @variety.destroy
      redirect_to varieties_path, notice: "Variety removed successfully."
    else
      redirect_to varieties_path, alert: @variety.errors.full_messages.to_sentence
    end
  end

  private
    def set_variety
      @variety = Variety.find(params[:id])
    end

    def load_commodity_options
      @commodities = commodity_options
    end

    def variety_params
      params.require(:variety).permit(:commodity_id, :name)
    end
end
