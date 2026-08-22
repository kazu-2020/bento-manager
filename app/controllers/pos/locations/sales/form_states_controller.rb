# frozen_string_literal: true

module Pos
  module Locations
    module Sales
      class FormStatesController < ApplicationController
        include PosLocationScoped
        include CartFormBuildable

        def create
          @form = build_form(submitted_params(:ghost_cart, form: ::Sales::CartForm))

          respond_to do |format|
            format.turbo_stream
          end
        end
      end
    end
  end
end
