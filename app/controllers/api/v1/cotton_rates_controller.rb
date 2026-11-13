module Api
  module V1
    # GET /api/v1/cotton_rates
    #
    # One day's cotton bulletin: raw cotton rates (mandi wise, gin wise, CCI,
    # TDN with moisture), candy rates (MCH / DCH), cotton seed rates and the
    # regional comparison. Pass ?date=2026-09-29, otherwise the latest
    # bulletin that has any rates is returned.
    class CottonRatesController < BaseController
      def index
        bulletin = find_bulletin
        return render_error(:not_found, "No cotton rates found#{" for #{params[:date]}" if params[:date].present?}.") if bulletin.nil?

        render json: {
          report_date: bulletin.report_date,
          title: bulletin.title,
          notes: bulletin.notes,
          raw_cotton_rates: CottonMarketObservation::CATEGORIES.except("comparison_sheet").to_h do |category, label|
            [ category, { label: label, rows: bulletin.observations_for(category).includes(:state, :district, :market).map { |row| observation_json(row) } } ]
          end,
          candy_rates: CandyRate::CATEGORIES.to_h do |category, label|
            [ category, { label: label, rows: bulletin.candy_rates_for(category).map { |row| candy_rate_json(row) } } ]
          end,
          cotton_seed_rates: bulletin.cotton_seed_rates.ordered.map { |row| seed_rate_json(row) },
          regional_comparison: bulletin.cotton_regional_comparisons.ordered.map { |row| regional_json(row) },
          updated_at: bulletin.updated_at
        }
      end

      private
        def find_bulletin
          scope = bulletins_with_rates.recent_first
          if params[:date].present?
            scope.find_by(report_date: date_param(:date))
          else
            scope.first
          end
        end

        # Opening a day in the web app creates an empty bulletin, so skip those.
        def bulletins_with_rates
          CottonBulletin.where(id: CottonMarketObservation.select(:cotton_bulletin_id))
            .or(CottonBulletin.where(id: CandyRate.select(:cotton_bulletin_id)))
            .or(CottonBulletin.where(id: CottonSeedRate.select(:cotton_bulletin_id)))
        end

        def observation_json(row)
          {
            name: row.market_label,
            state: named(row.state),
            district: named(row.district),
            market: named(row.market),
            observation_date: row.observation_date,
            arrival_quantity: number(row.arrival_quantity),
            arrival_price: row.arrival_price,
            minimum_price: number(row.minimum_price),
            maximum_price: number(row.maximum_price),
            modal_price: number(row.modal_price),
            moisture: row.moisture,
            total_arrival: number(row.total_arrival),
            traders_buy: number(row.traders_buy),
            traders_percentage: number(row.traders_percentage),
            cci_buy: number(row.cci_buy),
            cci_percentage: number(row.effective_cci_percentage),
            remarks: row.remarks
          }
        end

        def candy_rate_json(row)
          {
            parameter: row.parameter,
            madhya_pradesh_rate: row.madhya_pradesh_rate,
            madhya_pradesh_29mm_rate: row.madhya_pradesh_29mm_rate,
            maharashtra_29mm_rate: row.maharashtra_29mm_rate,
            maharashtra_31mm_rate: row.maharashtra_31mm_rate,
            odisha_29mm_rate: row.odisha_29mm_rate,
            odisha_30mm_rate: row.odisha_30mm_rate,
            reference: row.reference
          }
        end

        def seed_rate_json(row)
          {
            particular: row.particular,
            madhya_pradesh_rate: row.madhya_pradesh_rate,
            maharashtra_rate: row.maharashtra_rate,
            odisha_rate: row.odisha_rate,
            reference: row.reference
          }
        end

        def regional_json(row)
          {
            line_item: row.line_item,
            raipur: row.raipur_value,
            ojhar: row.ojhar_value,
            kukshi: row.kukshi_value,
            pati: row.pati_value,
            sausar: row.sausar_value,
            jobat: row.jobat_value,
            odisha: row.odisha_value,
            extra_one: row.extra_value_one,
            extra_two: row.extra_value_two
          }
        end
    end
  end
end
