# frozen_string_literal: true

module Locations
  module BasicInfoForm
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300 border-l-4 border-l-primary"

      def initialize(location:)
        @location = location
      end

      attr_reader :location

      delegate :inactive?, to: :location

      def frame_id
        Locations::BasicInfo::Component::FRAME_ID
      end

      def location_path
        helpers.location_path(location)
      end

      def card_classes
        if inactive?
          "#{CARD_CLASSES} opacity-75"
        else
          CARD_CLASSES
        end
      end

      def status_options
        Location.statuses.keys.map do |key|
          [I18n.t("enums.location.status.#{key}"), key]
        end
      end
    end
  end
end
