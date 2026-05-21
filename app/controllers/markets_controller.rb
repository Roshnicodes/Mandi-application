class MarketsController < ApplicationController
  include ReferenceCollections

  before_action :set_market, only: %i[edit update destroy]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @markets = Market.includes(district: :state).ordered
  end

  def new
    @market = Market.new
  end

  def create
    @market = Market.new(market_params)

    if @market.save
      redirect_to markets_path, notice: "Market created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @market.update(market_params)
      redirect_to markets_path, notice: "Market updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @market.destroy
      redirect_to markets_path, notice: "Market removed successfully."
    else
      redirect_to markets_path, alert: @market.errors.full_messages.to_sentence
    end
  end

  private
    def set_market
      @market = Market.find(params[:id])
    end

    def load_form_collections
      @states = state_options
      @districts_data = districts_payload
      @selected_state_id = @market&.district&.state_id
    end

    def market_params
      params.require(:market).permit(:district_id, :name)
    end
end
