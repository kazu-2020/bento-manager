# frozen_string_literal: true

module Discounts
  module StatusBadge
    class Component < Application::Component
      VARIANTS = {
        active:   "badge-success badge-soft",
        expired:  "badge-error badge-soft",
        upcoming: "badge-warning badge-soft"
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
