# frozen_string_literal: true

module Pos
  module Refunds
    module NewPage
      class Component < Application::Component
        def initialize(location:, sale:, form:)
          @location = location
          @sale = sale
          @form = form
        end

        attr_reader :location, :sale, :form

        delegate :items, :selected_items, :remaining_items, :has_selected_items?,
                 :all_items_selected?, :preview_refund_amount,
                 :form_with_options, :form_state_options,
                 to: :form

        def back_url
          helpers.pos_location_sales_history_index_path(location)
        end

        def form_state_url_with_sale_id
          helpers.pos_location_refunds_form_state_path(location, sale_id: sale.id)
        end

        def formatted_refund_amount
          helpers.number_to_currency(preview_refund_amount)
        end
      end
    end
  end
end
