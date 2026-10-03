class CottonBulletin < ApplicationRecord
  include AttachableRecord

  has_many :cotton_market_observations, dependent: :destroy
  has_many :cotton_seed_rates, dependent: :destroy
  has_many :candy_rates, dependent: :destroy
  has_many :cotton_regional_comparisons, dependent: :destroy
  has_many :cotton_call_performances, dependent: :destroy

  normalizes :title, with: ->(value) { value.to_s.squish }
  normalizes :notes, with: ->(value) { value.to_s.squish.presence }

  validates :report_date, :title, presence: true

  scope :recent_first, -> { order(report_date: :desc, created_at: :desc) }

  def self.daily_for(report_date)
    recent_first.find_by(report_date: report_date) || create!(
      report_date: report_date,
      title: default_title_for(report_date)
    )
  end

  def self.default_title_for(report_date)
    "Cotton Market Report · #{report_date.strftime("%d %b %Y")}"
  end

  def observations_for(category)
    cotton_market_observations.where(category: category).ordered
  end

  def candy_rates_for(category)
    candy_rates.where(category: category).ordered
  end
end
