# frozen_string_literal: true

module SalesHistories
  module MonthlySummary
    class Component < Application::Component
      def initialize(summary:)
        @summary = summary
      end

      private

      attr_reader :summary
    end
  end
end
