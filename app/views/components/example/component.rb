# frozen_string_literal: true

module Example
  class Component < Application::Component
    def initialize(title:)
      @title = title
    end

    attr_reader :title
  end
end
