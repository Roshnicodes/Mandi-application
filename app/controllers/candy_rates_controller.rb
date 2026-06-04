class CandyRatesController < CottonBulletinNestedController
  before_action :set_candy_rate, only: %i[edit update destroy]

  def new
    @candy_rate = @cotton_bulletin.candy_rates.new(category: params[:category])
  end

  def create
    @candy_rate = @cotton_bulletin.candy_rates.new(candy_rate_params)

    if @candy_rate.save
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Candy rate added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @candy_rate.update(candy_rate_params)
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Candy rate updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @candy_rate.destroy
    redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Candy rate removed successfully."
  end

  private
    def set_candy_rate
      @candy_rate = @cotton_bulletin.candy_rates.find(params[:id])
    end

    def candy_rate_params
      permit_with_attachments(
        :candy_rate,
        :category,
        :parameter,
        :madhya_pradesh_rate,
        :maharashtra_29mm_rate,
        :maharashtra_31mm_rate,
        :odisha_29mm_rate,
        :odisha_30mm_rate,
        :reference,
        :position
      )
    end
end
