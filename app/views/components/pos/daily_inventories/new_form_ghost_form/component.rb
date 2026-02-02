# frozen_string_literal: true

module Pos
  module DailyInventories
    module NewFormGhostForm
      class Component < Application::Component
        def initialize(form_state_options:, items:, search_query: nil)
          @form_state_options = form_state_options
          @items = items
          @search_query = search_query
        end

        attr_reader :form_state_options, :items, :search_query
      end
    end
  end
end
