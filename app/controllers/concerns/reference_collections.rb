module ReferenceCollections
  extend ActiveSupport::Concern

  private
    def state_options
      State.ordered
    end

    def district_options
      District.includes(:state).ordered
    end

    def market_options
      Market.includes(district: :state).ordered
    end

    def commodity_group_options
      CommodityGroup.ordered
    end

    def commodity_options
      Commodity.includes(:commodity_group).ordered
    end

    def variety_options
      Variety.includes(:commodity).ordered
    end

    def grade_options
      Grade.includes(:commodity, :variety).ordered
    end

    def price_unit_options
      PriceUnit.ordered
    end

    def arrival_unit_options
      ArrivalUnit.ordered
    end

    def districts_payload
      district_options.map do |district|
        {
          id: district.id,
          name: district.name,
          state_id: district.state_id
        }
      end
    end

    def markets_payload
      market_options.map do |market|
        {
          id: market.id,
          name: market.name,
          district_id: market.district_id,
          state_id: market.district.state_id
        }
      end
    end

    def commodities_payload
      commodity_options.map do |commodity|
        {
          id: commodity.id,
          name: commodity.name,
          label: commodity.label,
          commodity_group_id: commodity.commodity_group_id
        }
      end
    end

    def varieties_payload
      variety_options.map do |variety|
        {
          id: variety.id,
          name: variety.name,
          commodity_id: variety.commodity_id
        }
      end
    end

    def grades_payload
      grade_options.map do |grade|
        {
          id: grade.id,
          name: grade.name,
          commodity_id: grade.commodity_id,
          variety_id: grade.variety_id
        }
      end
    end
end
