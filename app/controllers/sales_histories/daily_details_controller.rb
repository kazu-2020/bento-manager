# frozen_string_literal: true

module SalesHistories
  class DailyDetailsController < ApplicationController
    def show
      location = Location.find(params[:location_id])
      date = parse_date

      calendar = Sales::HistoryCalendar.new(location: location, month: date)
      breakdown = calendar.daily_breakdown(date)

      daily_total = Sale.completed
                        .at_location(location)
                        .in_period(date.in_time_zone.beginning_of_day, date.in_time_zone.end_of_day)
                        .sum(:final_amount)

      render SalesHistories::DailyDetailPanel::Component.new(
        date: date,
        location: location,
        breakdown: breakdown,
        daily_total: daily_total
      ), layout: false
    end

    private

    def parse_date
      Date.parse(params[:date])
    rescue Date::Error, TypeError
      Date.current
    end
  end
end
