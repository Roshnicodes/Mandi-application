class CommodityGroupsController < ApplicationController
  before_action :set_commodity_group, only: %i[edit update destroy]

  def index
    @commodity_groups = CommodityGroup.ordered
  end

  def new
    @commodity_group = CommodityGroup.new
  end

  def create
    @commodity_group = CommodityGroup.new(commodity_group_params)

    if @commodity_group.save
      redirect_to commodity_groups_path, notice: "Commodity group created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @commodity_group.update(commodity_group_params)
      redirect_to commodity_groups_path, notice: "Commodity group updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @commodity_group.destroy
      redirect_to commodity_groups_path, notice: "Commodity group removed successfully."
    else
      redirect_to commodity_groups_path, alert: @commodity_group.errors.full_messages.to_sentence
    end
  end

  private
    def set_commodity_group
      @commodity_group = CommodityGroup.find(params[:id])
    end

    def commodity_group_params
      params.require(:commodity_group).permit(:name, :description)
    end
end
