# frozen_string_literal: true

module Pos
  module DailyInventories
    module NewFormSubmitButton
      class Component < Application::Component
        def initialize(disabled:, selected_count:)
          @disabled = disabled
          @selected_count = selected_count
        end

        def disabled?
          @disabled
        end

        attr_reader :selected_count
      end
    end
  end
end
