# frozen_string_literal: true

module Pos
  module Locations
    class SalesController < ApplicationController
      before_action :set_location
      before_action :set_inventories
      before_action :set_discounts

      def new
        @form = build_form
      end

      def create
        @form = build_form(submitted_params(:cart))

        unless @form.submittable?
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
      rescue Errors::MissingPriceError => e
        flash.now[:alert] = e.message
        render :new, status: :unprocessable_entity
      rescue DailyInventory::InsufficientStockError => e
        flash.now[:alert] = e.message
        render :new, status: :unprocessable_entity
      end

      private

      def set_location
        @location = Location.active.find(params[:location_id])
      end

      def set_inventories
        @inventories = @location.today_inventories.includes(:catalog).order("catalogs.name")
      end

      def set_discounts
        @discounts = Discount.active
      end

      def build_form(submitted = {})
        ::Sales::CartForm.new(
          location: @location,
          inventories: @inventories,
          discounts: @discounts,
          submitted: submitted
        )
      end

      def submitted_params(key)
        return {} unless params[key]

        params[key].to_unsafe_h
      end

      def current_employee
        return nil unless rodauth(:employee).logged_in?

        Employee.find_by(id: rodauth(:employee).session_value)
      end
    end
  end
end
