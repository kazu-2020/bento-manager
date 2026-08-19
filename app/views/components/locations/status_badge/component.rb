# frozen_string_literal: true

module Locations
  module StatusBadge
    class Component < Application::Component
      VARIANTS = {
        active:   "badge-success badge-soft",
        inactive: "badge-error badge-soft"
      }.freeze

      def initialize(status:)
        @status = status.to_sym
      end

      def variant_class
        VARIANTS.fetch(status)
      end

      def label
        I18n.t("enums.location.status.#{status}")
      end

      private

      attr_reader :status
    end
  end
end
