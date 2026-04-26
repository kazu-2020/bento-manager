# frozen_string_literal: true

module SalesHistories
  class DailyDetailsController < ApplicationController
    def show
      location = find_location
      date = parse_date
      calendar = Sales::HistoryCalendar.new(location: location, month: date)
      breakdown = calendar.daily_breakdown(date)
      daily_total = calendar.daily_totals[date] || 0

      render SalesHistories::DailyDetailPanel::Component.new(
        date: date,
        location: location,
        breakdown: breakdown,
        daily_total: daily_total
      ), layout: false
    end

    private

    def find_location
      Location.find(params[:location_id])
    end

    def parse_date
      Date.parse(params[:date])
    rescue Date::Error, TypeError
      Date.current
    end
  end
end
