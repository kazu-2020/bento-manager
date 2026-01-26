# frozen_string_literal: true

module Toast
  class Component < Application::Component
    VALID_TYPES = %i[success error warning info].freeze

    TYPE_ALERT_CLASSES = {
      success: "alert-success alert-soft",
      error: "alert-error alert-soft",
      warning: "alert-warning alert-soft",
      info: "alert-info alert-soft"
    }.freeze

    attr_reader :message, :type, :dismissible

    def initialize(message:, type: :success, dismissible: true)
      @message = message
      @type = normalize_type(type)
      @dismissible = dismissible
    end

    def alert_classes
      TYPE_ALERT_CLASSES[type]
    end

    def icon_name
      helpers.class_names("icons/#{type}")
    end

    private

    def normalize_type(value)
      type_sym = value.to_sym
      VALID_TYPES.include?(type_sym) ? type_sym : :info
    end
  end
end
