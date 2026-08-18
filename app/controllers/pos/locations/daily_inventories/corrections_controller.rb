# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class CorrectionsController < ApplicationController
        include SubmittedParamsFilterable

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
          @form = build_form(submitted_params(:inventory, form: ::DailyInventories::CorrectionForm))

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

        def build_form(submitted = ::GhostForms::Submission.absent)
          ::DailyInventories::CorrectionForm.new(
            location: @location, catalogs: @catalogs, submitted: submitted
          )
        end
      end
    end
  end
end
