class CottonSeedRatesController < CottonBulletinNestedController
  before_action :set_cotton_seed_rate, only: %i[edit update destroy]

  def new
    @cotton_seed_rate = @cotton_bulletin.cotton_seed_rates.new
  end

  def create
    @cotton_seed_rate = @cotton_bulletin.cotton_seed_rates.new(cotton_seed_rate_params)

    if @cotton_seed_rate.save
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton seed rate added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cotton_seed_rate.update(cotton_seed_rate_params)
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton seed rate updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cotton_seed_rate.destroy
    redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton seed rate removed successfully."
  end

  private
    def set_cotton_seed_rate
      @cotton_seed_rate = @cotton_bulletin.cotton_seed_rates.find(params[:id])
    end

    def cotton_seed_rate_params
      params.require(:cotton_seed_rate).permit(
        :particular,
        :madhya_pradesh_rate,
        :odisha_rate,
        :maharashtra_rate,
        :reference,
        :position
      )
    end
end
