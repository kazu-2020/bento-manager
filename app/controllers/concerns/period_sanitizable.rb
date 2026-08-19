# frozen_string_literal: true

module PeriodSanitizable
  DEFAULT_PERIOD = 30

  private

  def sanitize_period
    period = params[:period].to_i
    SalesAnalyses::FilterBar::Component::PERIODS.include?(period) ? period : DEFAULT_PERIOD
  end
end
