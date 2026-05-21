class CottonCallPerformancesController < CottonBulletinNestedController
  before_action :set_cotton_call_performance, only: %i[edit update destroy]

  def new
    @cotton_call_performance = @cotton_bulletin.cotton_call_performances.new
  end

  def create
    @cotton_call_performance = @cotton_bulletin.cotton_call_performances.new(cotton_call_performance_params)

    if @cotton_call_performance.save
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Call performance added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cotton_call_performance.update(cotton_call_performance_params)
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Call performance updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cotton_call_performance.destroy
    redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Call performance removed successfully."
  end

  private
    def set_cotton_call_performance
      @cotton_call_performance = @cotton_bulletin.cotton_call_performances.find(params[:id])
    end

    def cotton_call_performance_params
      params.require(:cotton_call_performance).permit(
        :total_calls,
        :fully_satisfied,
        :satisfaction_percent,
        :call_again,
        :wrong_call,
        :invalid_exist,
        :position
      )
    end
end
