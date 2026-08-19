# frozen_string_literal: true

module OverlayBadge
  class Component < Application::Component
    renders_one :badge

    def initialize(overlaid:)
      @overlaid = overlaid
    end

    def overlaid?
      @overlaid
    end
  end
end
