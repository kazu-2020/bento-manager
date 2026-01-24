# frozen_string_literal: true

module Catalogs
  module Prices
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"
      COMPONENT_ID = "catalog_prices_component"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      delegate :discontinued?, to: :catalog

      def component_id
        COMPONENT_ID
      end

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

      def price_edit_path(kind)
        helpers.edit_catalog_catalog_price_path(catalog, kind)
      end

      def show_edit_buttons?
        !discontinued?
      end

      def show_bundle_price?
        catalog.side_menu?
      end

      private

      def format_price(price)
        return nil unless price

        helpers.number_to_currency(price.price)
      end
    end
  end
end
