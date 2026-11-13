module Api
  module V1
    # GET /api/v1/daily_rates
    #
    # Mandi-wise min / max / modal prices and arrivals from the daily reports.
    # With no date filter it returns the most recent report date.
    #
    # Filters: date, from_date, to_date, state_id, district_id, market_id,
    #          commodity_group_id, commodity_id, variety_id, q (text search)
    # Paging:  page (default 1), per_page (default 100, max 500)
    class DailyRatesController < BaseController
      DEFAULT_PER_PAGE = 100
      MAX_PER_PAGE = 500

      def index
        filters = params.permit(:state_id, :district_id, :market_id, :commodity_group_id, :commodity_id, :variety_id, :q)
          .to_h.symbolize_keys

        from_date, to_date = requested_date_range
        if from_date.nil? && to_date.nil?
          latest = DailyPriceArrivalReport.filtered(filters).unscope(:order, :includes).maximum(:arrival_date)
          from_date = to_date = latest
        end
        filters[:from_date] = from_date
        filters[:to_date] = to_date

        reports = DailyPriceArrivalReport.filtered(filters)
        total = reports.unscope(:order).count
        per_page = params[:per_page].present? ? params[:per_page].to_i.clamp(1, MAX_PER_PAGE) : DEFAULT_PER_PAGE
        page = [ params[:page].to_i, 1 ].max

        render json: {
          from_date: from_date,
          to_date: to_date,
          page: page,
          per_page: per_page,
          total_count: total,
          total_pages: (total.to_f / per_page).ceil,
          rates: reports.offset((page - 1) * per_page).limit(per_page).map { |report| rate_json(report) }
        }
      end

      private
        def requested_date_range
          if params[:date].present?
            date = date_param(:date)
            [ date, date ]
          else
            [ date_param(:from_date), date_param(:to_date) ]
          end
        end

        def rate_json(report)
          {
            id: report.id,
            arrival_date: report.arrival_date,
            state: named(report.state),
            district: named(report.district),
            market: named(report.market),
            commodity_group: named(report.commodity_group),
            commodity: named(report.commodity),
            variety: named(report.variety),
            grade: named(report.grade),
            min_price: number(report.min_price),
            max_price: number(report.max_price),
            modal_price: number(report.modal_price),
            price_unit: report.price_unit.short_name.presence || report.price_unit.name,
            arrival_quantity: number(report.arrival_quantity),
            arrival_unit: report.arrival_unit.short_name.presence || report.arrival_unit.name,
            reference: report.remarks,
            attachments: attachments_json(report),
            updated_at: report.updated_at
          }
        end
    end
  end
end
