# frozen_string_literal: true

module Pos
  module Locations
    module Sales
      class FormStatesController < ApplicationController
        before_action :set_location
        before_action :set_inventories
        before_action :set_discounts

        def create
          @form = build_form(submitted_params(:ghost_cart))

          respond_to do |format|
            format.turbo_stream
          end
        end

        private

        def set_location
          @location = Location.active.find(params[:location_id])
        end

        def set_inventories
          @inventories = @location
                            .today_inventories
                            .eager_load(:catalog)
                            .merge(Catalog.category_order)
        end

        def set_discounts
          @discounts = Discount.preload(:discountable).active
        end

        def build_form(submitted = {})
          ::Sales::CartForm.new(
            location: @location,
            inventories: @inventories,
            discounts: @discounts,
            submitted: submitted
          )
        end

        def submitted_params(key)
          return {} unless params[key]

          params[key].to_unsafe_h
        end
      end
    end
  end
end
