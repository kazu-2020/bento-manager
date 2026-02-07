# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class CorrectionsController < ApplicationController
        before_action :set_location
        before_action :set_catalogs

        def new
          unless @location.has_today_inventory?
            redirect_to new_pos_location_daily_inventory_path(@location)
            return
          end

          @form = build_form
        end

        def create
          @form = build_form(submitted_params(:inventory))

          if @form.save
            redirect_to new_pos_location_sale_path(@location),
                        notice: t(".success", count: @form.registered_count)
          else
            flash.now[:alert] = @form.errors.full_messages.first
            render :new, status: :unprocessable_entity
          end
        end

        private

        def set_location
          @location = Location.active.find(params[:location_id])
        end

        def set_catalogs
          @catalogs = Catalog.available.category_order
        end

        def existing_inventories
          @existing_inventories ||= @location.today_inventories.index_by(&:catalog_id)
        end

        def build_form(submitted = {})
          submitted = default_submitted if submitted.empty?

          ::DailyInventories::CorrectionForm.new(
            location: @location,
            catalogs: @catalogs,
            submitted: submitted
          )
        end

        def default_submitted
          existing_inventories.transform_keys(&:to_s).transform_values do |inv|
            { "selected" => "1", "stock" => inv.stock.to_s }
          end
        end

        def submitted_params(key)
          return {} unless params[key]

          params[key].to_unsafe_h
        end
      end
    end
  end
end
