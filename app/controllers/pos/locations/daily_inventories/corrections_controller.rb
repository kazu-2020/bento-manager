# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class CorrectionsController < ApplicationController
        include PosLocationScoped
        include SubmittedParamsFilterable

        before_action :set_catalogs
        before_action :redirect_unless_correctable, only: :new
        before_action :set_additional_order_quantities

        def new
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

        def set_catalogs
          @catalogs = Catalog.available_or_stocked_at(@location).category_order
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

        # いまの在庫数に含まれているのは、当日在庫が作られた（登録または訂正された）
        # 後の追加発注だけ。訂正後の当日在庫は宣言された個数そのものなので、それ以前の
        # 発注まで出すと「この数量は追加発注を含んでいる」という偽の説明になる。
        def set_additional_order_quantities
          @additional_order_quantities = AdditionalOrder.quantities_by_catalog_id(
            location: @location,
            since: @location.today_inventories.minimum(:created_at)
          )
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
