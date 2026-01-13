# frozen_string_literal: true

module Locations
  module BasicInfo
    class Component < Application::Component
      FRAME_ID = "location_basic_info_frame"
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(location:)
        @location = location
      end

      attr_reader :location

      delegate :name, :status, :active?, :inactive?, to: :location

      def frame_id
        FRAME_ID
      end

      def edit_path
        helpers.edit_location_path(location)
      end

      def card_classes
        helpers.class_names(CARD_CLASSES, "opacity-75" => inactive?)
      end

      def created_at_formatted
        helpers.l(location.created_at, format: :long) if location.created_at
      end

      def updated_at_formatted
        helpers.l(location.updated_at, format: :long) if location.updated_at
      end
    end
  end
end
