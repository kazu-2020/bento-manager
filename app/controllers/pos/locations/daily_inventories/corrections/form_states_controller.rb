# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      module Corrections
        class FormStatesController < ApplicationController
          include PosLocationScoped
          include SubmittedParamsFilterable

          before_action :set_catalogs

          def create
            @form = build_form(submitted_params(:ghost_inventory, form: ::DailyInventories::CorrectionForm))

            respond_to do |format|
              # 新規登録と同じ turbo_stream テンプレートを共有
              format.turbo_stream do
                render "pos/locations/daily_inventories/form_states/create"
              end
            end
          end

          private

          def set_catalogs
            @catalogs = Catalog.available_or_stocked_at(@location).category_order
          end

          def build_form(submitted)
            ::DailyInventories::CorrectionForm.new(
              location: @location, catalogs: @catalogs,
              search_query: params[:search_query], submitted: submitted
            )
          end
        end
      end
    end
  end
end
