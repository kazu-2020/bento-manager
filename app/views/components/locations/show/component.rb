# frozen_string_literal: true

module Locations
  module Show
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(location:)
        @location = location
      end

      attr_reader :location

      delegate :name, :status, :active?, :inactive?, to: :location

      def back_path
        helpers.locations_path
      end

      def has_sales_history?
        return false unless location.persisted?

        location.sales.completed.exists?
      end
    end
  end
end
