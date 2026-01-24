# frozen_string_literal: true

module Catalogs
  module Discontinuation
    class Component < Application::Component
      CARD_CLASSES = "card bg-error/10 shadow-sm border-2 border-error/30"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      def render?
        catalog.discontinued?
      end

      def discontinuation
        catalog.discontinuation
      end

      def discontinued_at_formatted
        helpers.l(discontinuation.discontinued_at, format: :long) if discontinuation&.discontinued_at
      end

      def reason
        discontinuation&.reason
      end
    end
  end
end
