# frozen_string_literal: true

module Catalogs
  module StatusBadge
    class Component < Application::Component
      VARIANTS = {
        available:    "badge-success badge-soft",
        discontinued: "badge-error badge-soft"
      }.freeze

      def initialize(catalog:)
        @catalog = catalog
      end

      def status
        catalog.discontinued? ? :discontinued : :available
      end

      def variant_class
        VARIANTS.fetch(status)
      end

      private

      attr_reader :catalog
    end
  end
end
