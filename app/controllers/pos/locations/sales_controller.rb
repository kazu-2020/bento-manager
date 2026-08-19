# frozen_string_literal: true

module Pos
  module Locations
    class SalesController < ApplicationController
      include SubmittedParamsFilterable

      before_action :set_location
      before_action :set_inventories
      before_action :redirect_unless_inventories, only: :new
      before_action :set_discounts

      def new
        @re_registerable = !@location.sales_started_today?
        @form = build_form
      end

      def create
        @form = build_form(submitted_params(:cart, form: ::Sales::CartForm))

        unless @form.valid?
          flash.now[:alert] = t(".missing_requirements")
          return render :new, status: :unprocessable_entity
        end

        recorder = ::Sales::Recorder.new
        recorder.record(
          { location: @location, customer_type: @form.customer_type.to_sym, employee: current_employee },
          @form.cart_items_for_calculator,
          discount_quantities: @form.discount_quantities_for_calculator
        )

        redirect_to new_pos_location_sale_path(@location), notice: t(".success")
      rescue Errors::MissingPriceError, DailyInventory::InsufficientStockError => e
        flash.now[:alert] = e.message
        render :new, status: :unprocessable_entity
      end

      private

      def redirect_unless_inventories
        return if @inventories.present?

        redirect_to new_pos_location_daily_inventory_path(@location)
      end

      def set_location
        @location = Location.active.find(params[:location_id])
      end

      def set_inventories
        @inventories = @location
                          .today_inventories
                          .eager_load(:catalog)
                          .preload(catalog: :prices)
                          .merge(Catalog.category_order)
      end

      def set_discounts
        @discounts = Discount.preload(:discountable).active
      end

      def build_form(submitted = ::GhostForms::Submission.absent)
        ::Sales::CartForm.new(
          location: @location,
          inventories: @inventories,
          discounts: @discounts,
          submitted: submitted
        )
      end
    end
  end
end
