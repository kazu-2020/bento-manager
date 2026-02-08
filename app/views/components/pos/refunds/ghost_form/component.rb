# frozen_string_literal: true

module Pos
  module Refunds
    module GhostForm
      class Component < Application::Component
        def initialize(form:, sale:, location:)
          @form = form
          @sale = sale
          @location = location
        end

        attr_reader :form, :sale, :location

        delegate :corrected_items, :coupon_quantities, :available_discounts, to: :form

        def form_state_url
          helpers.pos_location_refunds_form_state_path(location, sale_id: sale.id)
        end
      end
    end
  end
end
