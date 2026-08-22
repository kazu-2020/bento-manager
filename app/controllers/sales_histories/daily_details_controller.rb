# frozen_string_literal: true

module SalesHistories
  class DailyDetailsController < ApplicationController
    def show
      location = Location.find(params[:location_id])
      date = parse_date
      calendar = Sales::HistoryCalendar.new(location: location, month: date)

      render SalesHistories::DailyDetailPanel::Component.new(
        date: date,
        location: location,
        breakdown: calendar.daily_breakdown(date),
        transaction_count: calendar.transaction_count(date)
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
