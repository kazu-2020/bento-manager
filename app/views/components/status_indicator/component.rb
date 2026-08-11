# frozen_string_literal: true

module StatusIndicator
  class Component < Application::Component
    def initialize(flagged:, label:)
      @flagged = flagged
      @label = label
    end

    attr_reader :label

    def flagged?
      @flagged
    end
  end
end
