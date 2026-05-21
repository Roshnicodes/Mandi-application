class CottonRegionalComparisonsController < CottonBulletinNestedController
  before_action :set_cotton_regional_comparison, only: %i[edit update destroy]

  def new
    @cotton_regional_comparison = @cotton_bulletin.cotton_regional_comparisons.new
  end

  def create
    @cotton_regional_comparison = @cotton_bulletin.cotton_regional_comparisons.new(cotton_regional_comparison_params)

    if @cotton_regional_comparison.save
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Regional comparison line added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cotton_regional_comparison.update(cotton_regional_comparison_params)
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Regional comparison updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cotton_regional_comparison.destroy
    redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Regional comparison removed successfully."
  end

  private
    def set_cotton_regional_comparison
      @cotton_regional_comparison = @cotton_bulletin.cotton_regional_comparisons.find(params[:id])
    end

    def cotton_regional_comparison_params
      params.require(:cotton_regional_comparison).permit(
        :line_item,
        :raipur_value,
        :ojhar_value,
        :kukshi_value,
        :pati_value,
        :sausar_value,
        :jobat_value,
        :odisha_value,
        :extra_value_one,
        :extra_value_two,
        :position
      )
    end
end
