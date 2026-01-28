# frozen_string_literal: true

module Pos
  module SalesHistory
    module IndexPage
      class Component < Application::Component
        def initialize(location:, sales:, daily_summary:)
          @location = location
          @sales = sales
          @daily_summary = daily_summary
        end

        attr_reader :location, :sales, :daily_summary

        def has_sales?
          sales.present?
        end

        def completed_sales
          sales.select(&:completed?)
        end

        def back_url
          helpers.pos_location_path(location)
        end

        def render_daily_summary
          render Pos::SalesHistory::DailySummary::Component.new(summary: daily_summary)
        end

        def render_sale_item_card(sale)
          render Pos::SalesHistory::SaleItemCard::Component.new(
            sale: sale,
            location: location
          )
        end

        def render_empty_state
          render Pos::SalesHistory::EmptyState::Component.new
        end
      end
    end
  end
end
