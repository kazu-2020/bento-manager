# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class FormStatesController < ApplicationController
        include DailyInventoryFormBuildable

        def create
          @form = build_form(submitted_params(:ghost_inventory, form: ::DailyInventories::InventoryForm))

          respond_to do |format|
            format.turbo_stream
          end
        end
      end
    end
  end
end
