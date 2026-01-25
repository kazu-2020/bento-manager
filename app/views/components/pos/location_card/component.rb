# frozen_string_literal: true

module Pos
  module LocationCard
    class Component < Application::Component
      with_collection_parameter :location

      BASE_CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300 w-full"

      def initialize(location:)
        @location = location
      end

      attr_reader :location

      delegate :name, :has_today_inventory?, to: :location

      def card_classes
        helpers.class_names(
          BASE_CARD_CLASSES,
          "cursor-pointer hover:shadow-md transition-shadow"
        )
      end
    end
  end
end
