# frozen_string_literal: true

module Pos
  module Locations
    module Refunds
      class FormStatesController < ApplicationController
        before_action :set_location
        before_action :set_sale

        def create
          @form = build_form(submitted_params(:ghost_refund))

          respond_to do |format|
            format.turbo_stream
          end
        end

        private

        def set_location
          @location = Location.active.find(params[:location_id])
        end

        def set_sale
          @sale = @location.sales
                           .eager_load(items: :catalog)
                           .find(params[:sale_id])
        end

        def build_form(submitted = {})
          ::Refunds::RefundForm.new(
            sale: @sale,
            location: @location,
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
