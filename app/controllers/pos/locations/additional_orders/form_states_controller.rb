# frozen_string_literal: true

module Pos
  module Locations
    module AdditionalOrders
      class FormStatesController < ApplicationController
        include PosLocationScoped
        include AdditionalOrderFormBuildable
        def create
          @form = build_form(submitted_params(:ghost_order, form: ::AdditionalOrders::OrderForm))

          respond_to do |format|
            format.turbo_stream
          end
        end
      end
    end
  end
end
