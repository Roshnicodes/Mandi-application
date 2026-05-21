class GradesController < ApplicationController
  include ReferenceCollections

  before_action :set_grade, only: %i[edit update destroy]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @grades = Grade.includes(:commodity, :variety).ordered
  end

  def new
    @grade = Grade.new
  end

  def create
    @grade = Grade.new(grade_params)

    if @grade.save
      redirect_to grades_path, notice: "Grade created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @grade.update(grade_params)
      redirect_to grades_path, notice: "Grade updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @grade.destroy
      redirect_to grades_path, notice: "Grade removed successfully."
    else
      redirect_to grades_path, alert: @grade.errors.full_messages.to_sentence
    end
  end

  private
    def set_grade
      @grade = Grade.find(params[:id])
    end

    def load_form_collections
      @commodities = commodity_options
      @varieties_data = varieties_payload
      @selected_commodity_id = @grade&.commodity_id
    end

    def grade_params
      params.require(:grade).permit(:commodity_id, :variety_id, :name)
    end
end
