class CottonMarketObservationsController < CottonBulletinNestedController
  GridRow = Struct.new(
    :id,
    :grid_index,
    :name,
    :position,
    :remarks,
    :arrival_quantity,
    :minimum_price,
    :maximum_price,
    :modal_price,
    :attachments,
    :records,
    :custom,
    :market,
    keyword_init: true
  ) do
    def all_values_blank?
      arrival_quantity.blank? && minimum_price.blank? && maximum_price.blank? && modal_price.blank?
    end

    def populated?
      arrival_quantity.present? || minimum_price.present? || maximum_price.present? || modal_price.present?
    end

    def saved_count
      Array(records).size
    end

    def custom?
      !!custom
    end
  end

  before_action :set_cotton_market_observation, only: %i[edit update destroy]
  before_action :set_template_category, only: %i[grid save_grid]
  before_action :redirect_template_categories_to_grid, only: :new

  def new
    @cotton_market_observation = @cotton_bulletin.cotton_market_observations.new(category: params[:category])
  end

  def grid
    prepare_grid_state(@category)
  end

  def save_grid
    @active_row_index = params[:active_row_index].to_s.presence
    all_grid_rows = build_grid_rows(@category, grid_rows_params)
    @active_row_name = all_grid_rows.find { |row| row.grid_index.to_s == @active_row_index.to_s }&.name
    @grid_rows = filter_grid_rows(all_grid_rows)
    @mandi_names = all_grid_rows.map(&:name)
    @custom_mandi_observation = @cotton_bulletin.cotton_market_observations.new(category: @category)
    @grid_errors = []
    success = true
    submitted_indexes = grid_rows_params.keys.map(&:to_s)

    CottonMarketObservation.transaction do
      all_grid_rows.each do |row|
        next unless submitted_indexes.include?(row.grid_index.to_s)
        next if row.all_values_blank?

        observation = @cotton_bulletin.cotton_market_observations.new(category: @category)

        observation.assign_attributes(
          category: @category,
          name: row.name,
          position: row.position,
          remarks: row.remarks,
          arrival_quantity: row.arrival_quantity,
          minimum_price: row.minimum_price,
          maximum_price: row.maximum_price,
          modal_price: row.modal_price
        )

        observation.attachments.attach(row.attachments) if row.attachments.present?

        next if observation.save

        success = false
        @grid_errors << "#{row.name}: #{observation.errors.full_messages.to_sentence}"
        raise ActiveRecord::Rollback
      end
    end

    if success
      redirect_to grid_cotton_bulletin_cotton_market_observations_path(@cotton_bulletin, category: @category, mandi: @active_row_name.presence || params[:mandi].presence), notice: "#{CottonMarketObservation::CATEGORIES.fetch(@category)} row added successfully."
    else
      flash.now[:alert] = "Grid save nahi ho payi. Niche row-wise errors dekh lijiye."
      render :grid, status: :unprocessable_entity
    end
  end

  def create
    @cotton_market_observation = @cotton_bulletin.cotton_market_observations.new(cotton_market_observation_params)

    if @cotton_market_observation.save
      if return_to_grid?
        redirect_to grid_cotton_bulletin_cotton_market_observations_path(@cotton_bulletin, category: @cotton_market_observation.category, mandi: @cotton_market_observation.name), notice: "Cotton observation added successfully."
      else
        redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton observation added successfully."
      end
    else
      if return_to_grid? && CottonMarketObservation.template_grid_supported?(@cotton_market_observation.category)
        @category = @cotton_market_observation.category
        prepare_grid_state(@category)
        @show_custom_row = true
        flash.now[:alert] = "Custom mandi save nahi ho payi. Errors niche dekh lijiye."
        render :grid, status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
  end

  def update
    if @cotton_market_observation.update(cotton_market_observation_params)
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton observation updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    category = @cotton_market_observation.category
    mandi_name = @cotton_market_observation.name
    @cotton_market_observation.destroy
    if return_to_grid? && CottonMarketObservation.template_grid_supported?(category)
      redirect_to grid_cotton_bulletin_cotton_market_observations_path(@cotton_bulletin, category: category, mandi: params[:mandi].presence || mandi_name), notice: "Cotton observation removed successfully."
    else
      redirect_to cotton_bulletin_path(@cotton_bulletin), notice: "Cotton observation removed successfully."
    end
  end

  private
    def prepare_grid_state(category)
      @active_row_name = params[:active_mandi].to_s.presence
      @show_custom_row = params[:open].to_s == "custom"
      all_grid_rows = build_grid_rows(category)
      @mandi_names = all_grid_rows.map(&:name)
      @mandi_filter = params[:mandi].to_s.presence || @mandi_names.first
      @grid_rows = filter_grid_rows(all_grid_rows)
      @custom_mandi_observation ||= @cotton_bulletin.cotton_market_observations.new(category: category)
    end

    def set_template_category
      @category = params[:category].to_s
      return if CottonMarketObservation.template_grid_supported?(@category)

      redirect_to cotton_bulletin_path(@cotton_bulletin), alert: "Is section ke liye grid view available nahi hai."
    end

    def redirect_template_categories_to_grid
      category = params[:category].to_s
      return unless CottonMarketObservation.template_grid_supported?(category)
      return if params[:manual].present?

      redirect_to grid_cotton_bulletin_cotton_market_observations_path(@cotton_bulletin, category: category)
    end

    def set_cotton_market_observation
      @cotton_market_observation = @cotton_bulletin.cotton_market_observations.find(params[:id])
    end

    def build_grid_rows(category, rows_payload = nil)
      rows_index = @cotton_bulletin.cotton_market_observations
        .where(category: category)
        .order(created_at: :desc, id: :desc)
        .group_by(&:name)
      rows_input = rows_payload.to_h
      template_rows = CottonMarketObservation.template_rows_for(category)
      template_names = template_rows.map { |row| row[:name] }

      grid_rows = template_rows.each_with_index.map do |template_row, index|
        input = rows_input[index.to_s] || rows_input[index] || {}
        records = rows_index[template_row[:name]] || []
        record = records.first

        GridRow.new(
          id: input["id"].presence || record&.id,
          grid_index: index,
          name: template_row[:name],
          position: template_row[:position],
          remarks: input["remarks"].presence || record&.remarks.presence || template_row[:remarks],
          arrival_quantity: input.fetch("arrival_quantity", record&.arrival_quantity),
          minimum_price: input.fetch("minimum_price", record&.minimum_price),
          maximum_price: input.fetch("maximum_price", record&.maximum_price),
          modal_price: input.fetch("modal_price", record&.modal_price),
          attachments: extract_attachments(input),
          records: records,
          custom: false,
          market: record&.market
        )
      end

      custom_names = rows_index.keys.reject { |name| template_names.include?(name) }.sort

      custom_rows = custom_names.each_with_index.map do |name, offset|
        records = rows_index[name] || []
        record = records.first
        input_index = template_rows.size + offset
        input = rows_input[input_index.to_s] || rows_input[input_index] || {}

        GridRow.new(
          id: input["id"].presence || record&.id,
          grid_index: input_index,
          name: input["name"].presence || record&.name,
          position: record&.position.presence || (template_rows.size + offset + 1),
          remarks: input["remarks"].presence || record&.remarks,
          arrival_quantity: input.fetch("arrival_quantity", record&.arrival_quantity),
          minimum_price: input.fetch("minimum_price", record&.minimum_price),
          maximum_price: input.fetch("maximum_price", record&.maximum_price),
          modal_price: input.fetch("modal_price", record&.modal_price),
          attachments: extract_attachments(input),
          records: records,
          custom: true,
          market: record&.market
        )
      end

      grid_rows + custom_rows
    end

    def grid_rows_params
      raw_rows = params[:rows]
      return {} if raw_rows.blank?

      raw_rows.respond_to?(:to_unsafe_h) ? raw_rows.to_unsafe_h : raw_rows.to_h
    end

    def filter_grid_rows(rows)
      return rows if @mandi_filter.blank?

      rows.select { |row| row.name == @mandi_filter }
    end

    def extract_attachments(input)
      Array(input["attachments"]).reject(&:blank?)
    end

    def return_to_grid?
      params[:return_to_grid].present?
    end

    def cotton_market_observation_params
      permit_with_attachments(
        :cotton_market_observation,
        :category,
        :name,
        :state_id,
        :district_id,
        :market_id,
        :observation_date,
        :arrival_quantity,
        :minimum_price,
        :maximum_price,
        :modal_price,
        :moisture,
        :arrival_price,
        :total_arrival,
        :traders_buy,
        :cci_buy,
        :buy_percentage,
        :traders_percentage,
        :cci_percentage,
        :remarks,
        :position
      )
    end
end
