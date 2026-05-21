class StatesController < ApplicationController
  before_action :set_state, only: %i[edit update destroy]

  def index
    @states = State.ordered
  end

  def new
    @state = State.new
  end

  def create
    @state = State.new(state_params)

    if @state.save
      redirect_to states_path, notice: "State created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @state.update(state_params)
      redirect_to states_path, notice: "State updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @state.destroy
      redirect_to states_path, notice: "State removed successfully."
    else
      redirect_to states_path, alert: @state.errors.full_messages.to_sentence
    end
  end

  private
    def set_state
      @state = State.find(params[:id])
    end

    def state_params
      params.require(:state).permit(:name)
    end
end
