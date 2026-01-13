# frozen_string_literal: true

module Icons
  module Base
    class Component < Application::Component
      SIZES = {
        xs: "h-3 w-3",
        sm: "h-4 w-4",
        md: "h-5 w-5",
        lg: "h-6 w-6",
        xl: "h-8 w-8"
      }.freeze

      PIXEL_SIZES = {
        xs: 12,
        sm: 16,
        md: 20,
        lg: 24,
        xl: 32
      }.freeze

      def initialize(size: :md, extra_class: nil, stroke_width: 2)
        @size = size.to_sym
        @extra_class = extra_class
        @stroke_width = stroke_width
      end

      def icon_path
        raise NotImplementedError, "Subclasses must define icon_path"
      end

      def css_classes
        [ size_class, extra_class ].compact.join(" ")
      end

      attr_reader :stroke_width

      def pixel_size
        PIXEL_SIZES.fetch(size, PIXEL_SIZES[:md])
      end

      private

      attr_reader :size, :extra_class

      def size_class
        SIZES.fetch(size, SIZES[:md])
      end
    end
  end
end
