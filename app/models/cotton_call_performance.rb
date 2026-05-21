class CottonCallPerformance < ApplicationRecord
  belongs_to :cotton_bulletin

  before_validation :derive_satisfaction_percent

  validates :total_calls, :fully_satisfied, :call_again, :wrong_call, :invalid_exist,
            numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :satisfaction_percent, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  scope :ordered, -> { order(Arel.sql("COALESCE(position, 999999) ASC"), created_at: :asc) }

  private
    def derive_satisfaction_percent
      return if total_calls.to_i <= 0
      return if fully_satisfied.blank?

      self.satisfaction_percent = ((fully_satisfied.to_f / total_calls.to_f) * 100).round(2)
    end
end
