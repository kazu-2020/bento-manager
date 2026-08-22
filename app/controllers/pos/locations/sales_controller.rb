# frozen_string_literal: true

module Pos
  module Locations
    class SalesController < ApplicationController
      include PosLocationScoped
      include CartFormBuildable

      before_action :redirect_unless_inventories, only: :new

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
    end
  end
end
