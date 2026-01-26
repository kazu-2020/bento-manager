# frozen_string_literal: true

module Pos
  module DailyInventories
    module NewFormGhostForm
      class Component < Application::Component
        def initialize(form_state_options:, items:)
          @form_state_options = form_state_options
          @items = items
        end

        attr_reader :form_state_options, :items
      end
    end
  end
end
