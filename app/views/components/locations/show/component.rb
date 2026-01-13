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

      def edit_path
        helpers.edit_location_path(location)
      end

      def back_path
        helpers.locations_path
      end

      def created_at_formatted
        helpers.l(location.created_at, format: :long) if location.created_at
      end

      def updated_at_formatted
        helpers.l(location.updated_at, format: :long) if location.updated_at
      end

      def card_classes
        if inactive?
          "#{CARD_CLASSES} opacity-75"
        else
          CARD_CLASSES
        end
      end

      def has_sales_history?
        false
      end

      def has_inventory?
        false
      end
    end
  end
end
