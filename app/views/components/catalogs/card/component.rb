# frozen_string_literal: true

module Catalogs
  module Card
    class Component < Application::Component
      with_collection_parameter :catalog

      BASE_CARD_CLASSES = "card bg-base-100 shadow-sm border border-base-300 w-full"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      def show_path
        helpers.catalog_path(catalog)
      end

      def card_classes
        helpers.class_names(
          BASE_CARD_CLASSES,
          "opacity-50" => discontinued?,
          "hover:shadow-md hover:border-base-content/20 transition-all duration-200" => !discontinued?
        )
      end

      def discontinued?
        catalog.discontinued?
      end

      def regular_price
        catalog.price_by_kind(:regular)&.price
      end

      def bundle_price
        catalog.price_by_kind(:bundle)&.price
      end

      def formatted_regular_price
        helpers.number_to_currency(regular_price) if regular_price
      end

      def formatted_bundle_price
        helpers.number_to_currency(bundle_price) if bundle_price
      end

      def has_prices?
        regular_price.present? || bundle_price.present?
      end
    end
  end
end
