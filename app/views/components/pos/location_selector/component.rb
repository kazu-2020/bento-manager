# frozen_string_literal: true

module Pos
  module LocationSelector
    class Component < Application::Component
      def initialize(locations:)
        @locations = locations
      end

      attr_reader :locations

      def none?
        locations.none?
      end
    end
  end
end
