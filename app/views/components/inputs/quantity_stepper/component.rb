module Inputs
  module QuantityStepper
    class Component < Application::Component
      renders_one :input

      SIZES = %w[default compact].freeze

      def initialize(unit: nil, extra_class: nil, size: "default")
        raise ArgumentError, "Invalid size: #{size}. Must be one of: #{SIZES.join(', ')}" unless SIZES.include?(size)

        @unit = unit
        @extra_class = extra_class
        @size = size
      end

      attr_reader :unit, :extra_class, :size

      def compact? = size == "compact"

      def button_size_class = compact? ? "btn-sm" : "btn-lg"

      def icon_class = compact? ? "h-4 w-4" : "h-6 w-6"

      def gap_class = compact? ? "gap-2" : "gap-4"

      def unit_text_class = compact? ? "text-sm" : "text-lg"
    end
  end
end
