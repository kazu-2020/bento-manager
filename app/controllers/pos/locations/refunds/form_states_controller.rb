# frozen_string_literal: true

module Pos
  module Locations
    module Refunds
      class FormStatesController < ApplicationController
        include RefundFormBuildable

        before_action :set_location
        before_action :set_sale
        before_action :set_inventories

        def create
          @form = build_form(
            submitted_params(:ghost_refund, **::Refunds::RefundForm::SUBMITTED_PARAMS_SHAPE)
          )

          respond_to do |format|
            format.turbo_stream
          end
        end
      end
    end
  end
end
