module Inputs
  module QuantityStepper
    class Component < Application::Component
      renders_one :input

      def initialize(unit: nil, extra_class: nil, size: "default")
        @unit = unit
        @extra_class = extra_class
        @size = size
      end

      attr_reader :unit, :extra_class, :size

      def compact? = size == "compact"

      def button_size_class = compact? ? "btn-sm" : "btn-lg"

      def icon_class = compact? ? "h-4 w-4" : "h-6 w-6"

      def gap_class = compact? ? "gap-2" : "gap-4"
    end
  end
end
