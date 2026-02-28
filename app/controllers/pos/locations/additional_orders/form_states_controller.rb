# frozen_string_literal: true

module Pos
  module Locations
    module AdditionalOrders
      class FormStatesController < ApplicationController
        include AdditionalOrderFormBuildable

        before_action :set_location

        def create
          @form = build_form(submitted_params(:ghost_order))

          respond_to do |format|
            format.turbo_stream
          end
        end
      end
    end
  end
end
