module Inputs
  module QuantityStepper
    class Component < Application::Component
      renders_one :input

      def initialize(unit: nil, extra_class: nil)
        @unit = unit
        @extra_class = extra_class
      end

      attr_reader :unit, :extra_class
    end
  end
end
