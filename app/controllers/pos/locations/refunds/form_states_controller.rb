# frozen_string_literal: true

module Pos
  module Locations
    module Refunds
      class FormStatesController < ApplicationController
        include RefundFormBuildable

        def create
          @form = build_form(submitted_params(:ghost_refund, form: ::Refunds::RefundForm))

          respond_to do |format|
            format.turbo_stream
          end
        end
      end
    end
  end
end
