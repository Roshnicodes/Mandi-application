class MarketsController < ApplicationController
  include ReferenceCollections

  before_action :require_admin
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
      redirect_to after_quick_entry_create_path(@market), notice: "Market created successfully."
    else
      if quick_entry_request?
        redirect_back fallback_location: new_daily_price_arrival_report_path(state_id: @market.district&.state_id, district_id: @market.district_id), alert: @market.errors.full_messages.to_sentence
        return
      end

      if cotton_grid_request?
        redirect_back fallback_location: cotton_grid_fallback_path, alert: @market.errors.full_messages.to_sentence
        return
      end

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

    def quick_entry_request?
      params[:return_to_entry].present?
    end

    def cotton_grid_request?
      params[:return_to_cotton_grid].present?
    end

    def after_quick_entry_create_path(market)
      return after_cotton_grid_create_path(market) if cotton_grid_request?
      return markets_path unless quick_entry_request?

      new_daily_price_arrival_report_path(state_id: market.district.state_id, district_id: market.district_id, market_id: market.id)
    end

    def after_cotton_grid_create_path(market)
      grid_cotton_bulletin_cotton_market_observations_path(
        params[:cotton_bulletin_id],
        category: params[:category].presence || "mandi_wise",
        state_id: market.district.state_id,
        district_id: market.district_id,
        mandi: market.name
      )
    end

    def cotton_grid_fallback_path
      return cotton_bulletins_path if params[:cotton_bulletin_id].blank?

      grid_cotton_bulletin_cotton_market_observations_path(
        params[:cotton_bulletin_id],
        category: params[:category].presence || "mandi_wise",
        state_id: params[:selected_state_id].presence,
        district_id: params.dig(:market, :district_id).presence
      )
    end
end
