# frozen_string_literal: true

module PageHeader
  class Component < Application::Component
    def initialize(title:, new_path: nil, new_label: nil, turbo_stream: false)
      @title = title
      @new_path = new_path
      @new_label = new_label || I18n.t("helpers.link.new")
      @turbo_stream = turbo_stream
    end

    attr_reader :title, :new_path, :new_label

    def new_button?
      new_path.present?
    end

    def turbo_stream?
      @turbo_stream
    end
  end
end
