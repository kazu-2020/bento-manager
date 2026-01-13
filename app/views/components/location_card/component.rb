# frozen_string_literal: true

module LocationCard
  class Component < Application::Component
    with_collection_parameter :location

    BASE_CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300 w-full"

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
      helpers.class_names(
        BASE_CARD_CLASSES,
        "opacity-50" => inactive?,
        "hover:shadow-md transition-shadow" => !inactive?
      )
    end
  end
end
