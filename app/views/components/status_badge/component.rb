# frozen_string_literal: true

module StatusBadge
  class Component < Application::Component
    VARIANTS = {
      active: "badge-success badge-soft ",
      inactive: "badge-error badge-soft"
    }.freeze

    def initialize(status:, model: :location)
      @status = status.to_sym
      @model = model
    end

    def variant_class
      VARIANTS.fetch(status, "badge-ghost")
    end

    def label
      I18n.t("enums.#{model}.status.#{status}")
    end

    private

    attr_reader :status, :model
  end
end
