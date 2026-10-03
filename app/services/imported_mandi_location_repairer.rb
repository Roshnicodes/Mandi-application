class ImportedMandiLocationRepairer
  Result = Data.define(:moved, :deduplicated, :discarded, :removed_districts, :unresolved_market_names)

  def repair
    @moved = 0
    @deduplicated = 0
    @discarded = 0
    @removed_districts = 0
    @unresolved_market_names = []

    ActiveRecord::Base.transaction do
      imported_districts.find_each do |district|
        resolver = MandiLocationResolver.new(district.state)

        district.markets.includes(:daily_price_arrival_reports).find_each do |market|
          target_market = resolver.resolve(market.name)

          if target_market.present?
            move_reports(market, target_market)
            market.destroy! if market.daily_price_arrival_reports.reload.none?
          elsif MandiLocationResolver.date_like_market_name?(market.name)
            discard_invalid_market(market)
          else
            @unresolved_market_names << market.name
          end
        end

        if district.markets.none? && district.daily_price_arrival_reports.none?
          district.destroy!
          @removed_districts += 1
        end
      end
    end

    Result.new(
      moved: @moved,
      deduplicated: @deduplicated,
      discarded: @discarded,
      removed_districts: @removed_districts,
      unresolved_market_names: @unresolved_market_names.uniq.sort
    )
  end

  private
    def imported_districts
      District.includes(:state).where("LOWER(name) = ?", MandiLocationResolver::IMPORTED_DISTRICT_NAME.downcase)
    end

    def move_reports(source_market, target_market)
      source_market.daily_price_arrival_reports.find_each do |report|
        existing_report = target_market.daily_price_arrival_reports.where(
          arrival_date: report.arrival_date,
          commodity_id: report.commodity_id,
          variety_id: report.variety_id,
          grade_id: report.grade_id
        ).first

        if existing_report.present?
          report.destroy!
          @deduplicated += 1
        else
          report.update!(market: target_market)
          @moved += 1
        end
      end
    end

    def discard_invalid_market(market)
      market.daily_price_arrival_reports.find_each do |report|
        report.destroy!
        @discarded += 1
      end
      market.destroy! if market.daily_price_arrival_reports.reload.none?
    end
end
