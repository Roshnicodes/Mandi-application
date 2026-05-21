class State < ApplicationRecord
  has_many :districts, dependent: :restrict_with_error
  has_many :daily_price_arrival_reports, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :code, with: ->(value) { value.to_s.strip.upcase }

  before_validation :assign_internal_code

  validates :name, :code, presence: true
  validates :name, :code, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(:name) }

  private
    def assign_internal_code
      return if name.blank?
      return if code.present? && !will_save_change_to_name?

      tokens = name.to_s.parameterize(separator: " ").split
      base_code = tokens.filter_map { |token| token[0] }.join.first(3).to_s.upcase
      base_code = name.to_s.gsub(/[^A-Za-z]/, "").first(3).to_s.upcase if base_code.blank?
      base_code = "STA" if base_code.blank?

      candidate = base_code
      suffix = 1

      while self.class.where.not(id: id).exists?(code: candidate)
        suffix += 1
        candidate = "#{base_code.first(2)}#{suffix}".first(6)
      end

      self.code = candidate
    end
end
