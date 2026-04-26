# frozen_string_literal: true

class SalesHistoriesController < ApplicationController
  include LocationFindable

  def index
    @location = find_location
    @month = parse_month
    @calendar = Sales::HistoryCalendar.new(location: @location, month: @month)

    render SalesHistories::IndexPage::Component.new(
      location: @location,
      month: @month,
      calendar: @calendar,
      locations: Location.display_order
    )
  end

  def show
    @location = find_location
    @date = parse_date
    return redirect_to sales_histories_path unless @date

    @sales = Sale.at_location(@location)
                 .in_period(@date.beginning_of_day, @date.end_of_day)
                 .eager_load(:employee)
                 .preload(items: :catalog)
                 .order(:sale_datetime)

    render SalesHistories::ShowPage::Component.new(
      date: @date,
      location: @location,
      sales: @sales
    )
  end

  private

  def parse_month
    if params[:month].present?
      Date.strptime(params[:month], "%Y-%m")
    else
      Date.current
    end
  rescue Date::Error
    Date.current
  end

  def parse_date
    Date.parse(params[:id])
  rescue Date::Error, TypeError
    nil
  end
end
