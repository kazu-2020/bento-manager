module Locations
  module LocationList
    class Component < Application::Component
      def initialize(locations:)
        @locations = locations
      end

      attr_reader :locations

      def empty?
        locations.empty?
      end
    end
  end
end
