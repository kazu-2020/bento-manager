# frozen_string_literal: true

module Pos
  module Refunds
    module NewPage
      class Component < Application::Component
        def initialize(form:, sale:, location:)
          @form = form
          @sale = sale
          @location = location
        end

        attr_reader :form, :sale, :location

        delegate :grouped_items, :has_selected_items?, :form_with_options, to: :form

        def back_url
          helpers.pos_location_sales_history_index_path(location)
        end
      end
    end
  end
end
