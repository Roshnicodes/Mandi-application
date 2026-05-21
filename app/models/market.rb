class Market < ApplicationRecord
  MARKET_TYPES = [
    "APMC",
    "Cotton Yard",
    "Private Mandi",
    "Organic Market",
    "Other"
  ].freeze

  belongs_to :district
  has_one :state, through: :district

  has_many :daily_price_arrival_reports, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :code, with: ->(value) { value.to_s.strip.upcase }
  normalizes :market_type, with: ->(value) { value.to_s.squish.presence || "APMC" }

  before_validation :assign_market_type

  validates :name, presence: true, uniqueness: { scope: :district_id, case_sensitive: false }
  validates :market_type, presence: true, inclusion: { in: MARKET_TYPES }

  scope :ordered, -> { order(:name) }

  private
    def assign_market_type
      market_name = name.to_s.downcase

      self.market_type =
        if market_name.include?("cotton")
          "Cotton Yard"
        elsif market_name.include?("organic")
          "Organic Market"
        elsif market_name.include?("private")
          "Private Mandi"
        elsif market_name.include?("apmc")
          "APMC"
        else
          "Other"
        end
    end
end
