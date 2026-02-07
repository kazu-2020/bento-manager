# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      module Corrections
        class FormStatesController < ApplicationController
          before_action :set_location
          before_action :set_catalogs

          def create
            @form = build_form(submitted_params(:ghost_inventory))

            respond_to do |format|
              # 新規登録と同じ turbo_stream テンプレートを共有
              format.turbo_stream do
                render "pos/locations/daily_inventories/form_states/create"
              end
            end
          end

          private

          def set_location
            @location = Location.active.find(params[:location_id])
          end

          def set_catalogs
            @catalogs = Catalog.available.category_order
          end

          def build_form(submitted = {})
            items = ::DailyInventories::ItemBuilder.from_params(@catalogs, submitted)
            ::DailyInventories::CorrectionForm.new(
              location: @location, items: items, search_query: params[:search_query]
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
end
