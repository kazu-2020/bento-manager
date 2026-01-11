# frozen_string_literal: true

module LocationCard
  class Component < Application::Component
    BASE_CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

    def initialize(location:)
      @location = location
    end

    attr_reader :location

    def show_path
      helpers.location_path(location)
    end

    def inactive?
      location.inactive?
    end

    def card_classes
      if inactive?
        "#{BASE_CARD_CLASSES} opacity-50 w-full"
      else
        "#{BASE_CARD_CLASSES} hover:shadow-md transition-shadow"
      end
    end
  end
end
