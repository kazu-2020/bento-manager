# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      module Corrections
        class FormStatesController < ApplicationController
          include DailyInventoryCorrectionFormBuildable

          def create
            @form = build_form(submitted_params(:ghost_inventory, form: ::DailyInventories::CorrectionForm))

            respond_to do |format|
              # 新規登録と同じ turbo_stream テンプレートを共有
              format.turbo_stream do
                render "pos/locations/daily_inventories/form_states/create"
              end
            end
          end
        end
      end
    end
  end
end
