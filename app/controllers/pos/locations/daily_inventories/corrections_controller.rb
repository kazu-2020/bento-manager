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

        def existing_inventories
          @existing_inventories ||= @location.today_inventories.index_by(&:catalog_id)
        end

        # 初期値をどこから作るかだけを分ける。壊れた送信の差し戻しは
        # GhostForms::SubmissionReadable が担うので、ここで拒否の判断はしない
        def build_form(submitted = ::GhostForms::Submission.absent)
          items = if submitted.absent?
            ::DailyInventories::ItemBuilder.from_inventories(@catalogs, existing_inventories)
          else
            ::DailyInventories::ItemBuilder.from_params(@catalogs, submitted.values)
          end
          ::DailyInventories::CorrectionForm.new(
            location: @location, items: items, submitted: submitted
          )
        end
      end
    end
  end
end
