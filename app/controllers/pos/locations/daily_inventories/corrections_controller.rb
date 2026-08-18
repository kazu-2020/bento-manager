# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class CorrectionsController < ApplicationController
        include SubmittedParamsFilterable

        before_action :set_location
        before_action :set_catalogs
        before_action :redirect_unless_correctable, only: :new
        before_action :set_additional_order_quantities, only: :new

        def new
          @form = build_form
        end

        def create
          @form = build_form(submitted_params(:inventory, form: ::DailyInventories::CorrectionForm))

          if @form.save
            redirect_to new_pos_location_sale_path(@location),
                        notice: t(".success", count: @form.registered_count)
          else
            set_additional_order_quantities
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

        # 訂正は当日在庫があり、かつ販売開始前でなければ行えない。
        # 数量を入れ直したあとで拒否されるのを避けるため、入口で弾く。
        def redirect_unless_correctable
          unless @location.has_today_inventory?
            redirect_to new_pos_location_daily_inventory_path(@location)
            return
          end

          redirect_to new_pos_location_sale_path(@location) if @location.sales_started_today?
        end

        def set_additional_order_quantities
          @additional_order_quantities = @location.today_additional_order_quantities
        end

        def existing_inventories
          @existing_inventories ||= @location.today_inventories.index_by(&:catalog_id)
        end

        # 送信の有無で分岐する。フィルタ後の中身で分岐すると、不正なパラメータだけの
        # 送信が空に畳まれて既存在庫からの再構築に化け、拒否すべき要求が
        # bulk_recreate による破壊的な書き込みを行ってしまう。
        def build_form(submitted = nil)
          items = if submitted.nil?
            ::DailyInventories::ItemBuilder.from_inventories(@catalogs, existing_inventories)
          else
            ::DailyInventories::ItemBuilder.from_params(@catalogs, submitted)
          end
          ::DailyInventories::CorrectionForm.new(location: @location, items: items)
        end
      end
    end
  end
end
