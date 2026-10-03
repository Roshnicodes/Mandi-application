class MandiLocationResolver
  IMPORTED_DISTRICT_NAME = "Imported Markets"

  # The source workbooks contain the APMC name and state, but no district.
  # Keep the source-specific knowledge in one place so import and repair use
  # exactly the same canonical district and mandi records.
  MADHYA_PRADESH_MARKETS = {
    "agar" => { district: "Agar Malwa", market: "Agar" },
    "alirajpur" => { district: "Alirajpur", market: "Alirajpur" },
    "anjad" => { district: "Barwani", market: "Anjad" },
    "badwani" => { district: "Barwani", market: "Badwani" },
    "barwani" => { district: "Barwani", market: "Barwani" },
    "betul" => { district: "Betul", market: "Betul" },
    "chhindwara" => { district: "Chhindwara", market: "Chhindwara" },
    "dhamnod" => { district: "Dhar", market: "Dhamnod" },
    "dhar" => { district: "Dhar", market: "Dhar" },
    "indore" => { district: "Indore", market: "Indore" },
    "khargone" => { district: "Khargone", market: "Khargone" },
    "kukshi" => { district: "Dhar", market: "Kukshi" },
    "neemuch" => { district: "Neemuch", market: "Neemuch" },
    "petlawad" => { district: "Jhabua", market: "Petlawad" },
    "petlawadbamnia" => { district: "Jhabua", market: "Petlawad (Bamnia)" },
    "ratlam" => { district: "Ratlam", market: "Ratlam" },
    "saunsar" => { district: "Chhindwara", market: "Sausar" },
    "sausar" => { district: "Chhindwara", market: "Sausar" },
    "ujjain" => { district: "Ujjain", market: "Ujjain" },
    "vidisha" => { district: "Vidisha", market: "Vidisha" }
  }.freeze

  STATE_ALIASES = {
    "mp" => "madhyapradesh",
    "madhyapradesh" => "madhyapradesh"
  }.freeze

  def self.date_like_market_name?(value)
    value.to_s.squish.match?(%r{\A\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\z})
  end

  def self.normalized_market_name(name)
    name.to_s.downcase
      .gsub(/agriculture\s+produce\s+market\s+committee/, "")
      .gsub(/agricultural\s+produce\s+market\s+committee/, "")
      .gsub(/\bapmc\b/, "")
      .gsub(/[^a-z0-9]/, "")
  end

  def initialize(state)
    @state = state
  end

  def resolve(name)
    return if @state.blank? || self.class.date_like_market_name?(name)

    normalized_name = self.class.normalized_market_name(name)
    return if normalized_name.blank?

    existing_market = market_index[normalized_name]
    return existing_market if existing_market.present?

    location = locations[normalized_name]
    return unless location

    district = District.where(state: @state).where("LOWER(name) = ?", location.fetch(:district).downcase).first ||
      District.create!(state: @state, name: location.fetch(:district))
    market = district.markets.where("LOWER(name) = ?", location.fetch(:market).downcase).first ||
      Market.create!(district: district, name: location.fetch(:market))

    market_index[normalized_name] = market
  end

  def fallback_district
    District.where(state: @state).where("LOWER(name) = ?", IMPORTED_DISTRICT_NAME.downcase).first ||
      District.create!(state: @state, name: IMPORTED_DISTRICT_NAME)
  end

  private
    def market_index
      @market_index ||= Market.includes(:district)
        .joins(:district)
        .where(districts: { state_id: @state.id })
        .where.not("LOWER(districts.name) = ?", IMPORTED_DISTRICT_NAME.downcase)
        .index_by { |market| self.class.normalized_market_name(market.name) }
    end

    def locations
      return {} unless canonical_state_name == "madhyapradesh"

      MADHYA_PRADESH_MARKETS
    end

    def canonical_state_name
      normalized_name = @state.name.to_s.downcase.gsub(/[^a-z0-9]/, "")
      STATE_ALIASES.fetch(normalized_name, normalized_name)
    end
end
