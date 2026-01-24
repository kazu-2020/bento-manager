# frozen_string_literal: true

module CatalogStatusBadge
  class Component < Application::Component
    VARIANTS = {
      available: "badge-success badge-soft",
      discontinued: "badge-error badge-soft"
    }.freeze

    def initialize(catalog:)
      @catalog = catalog
    end

    def status
      @catalog.discontinued? ? :discontinued : :available
    end

    def variant_class
      VARIANTS.fetch(status, "badge-ghost")
    end

    def label
      I18n.t("catalogs.status.#{status}")
    end

    private

    attr_reader :catalog
  end
end
