# frozen_string_literal: true

module Catalogs
  module StatusBadge
    class Component < Application::Component
      VARIANTS = {
        available:    "badge-success badge-soft",
        discontinued: "badge-error badge-soft"
      }.freeze

      def initialize(status:)
        @status = status.to_sym
      end

      def variant_class
        VARIANTS.fetch(status)
      end

      def label
        t(".#{status}")
      end

      private

      attr_reader :status
    end
  end
end
