# frozen_string_literal: true

module Pos
  module SalesHistory
    module DailySummary
      class Component < Application::Component
        def initialize(summary:)
          @summary = summary
        end

        attr_reader :summary

        def total_count
          summary[:total_count]
        end

        def total_amount
          summary[:total_amount]
        end

        def voided_count
          summary[:voided_count]
        end

        def formatted_total_amount
          helpers.number_to_currency(total_amount)
        end

        def has_voided?
          voided_count > 0
        end
      end
    end
  end
end
