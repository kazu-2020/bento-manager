# frozen_string_literal: true

module SalesAnalyses
  module Ranking
    class Component < Application::Component
      def initialize(data:)
        @data = data
      end

      private

      attr_reader :data
    end
  end
end
