# frozen_string_literal: true

module Catalogs
  module Prices
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      delegate :discontinued?, to: :catalog

      def card_classes
        helpers.class_names(CARD_CLASSES, "opacity-75" => discontinued?)
      end

      def regular_price
        @regular_price ||= catalog.price_by_kind(:regular)
      end

      def bundle_price
        @bundle_price ||= catalog.price_by_kind(:bundle)
      end

      def regular_price_formatted
        format_price(regular_price)
      end

      def bundle_price_formatted
        format_price(bundle_price)
      end

      def has_any_price?
        regular_price || bundle_price
      end

      private

      def format_price(price)
        return nil unless price

        helpers.number_to_currency(price.price)
      end
    end
  end
end
