# frozen_string_literal: true

module Pos
  module SalesHistory
    module DailySummary
      class Component < Application::Component
        def initialize(summary:)
          @summary = summary
        end

        attr_reader :summary

        delegate :[], to: :summary

        def total_count
          self[:total_count]
        end

        def total_amount
          self[:total_amount]
        end

        def voided_count
          self[:voided_count]
        end

        def formatted_total_amount
          helpers.number_to_currency(total_amount)
        end

        def has_voided?
          voided_count.positive?
        end
      end
    end
  end
end
