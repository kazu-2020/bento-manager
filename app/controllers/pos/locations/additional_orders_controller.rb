# frozen_string_literal: true

module Pos
  module Locations
    class AdditionalOrdersController < ApplicationController
      include AdditionalOrderFormBuildable

      before_action :set_location
      before_action :set_inventories, only: :index
      before_action :redirect_unless_inventories
      before_action :set_additional_orders, only: :index

      def index
      end

      def new
        @form = build_form
      end

      def create
        @form = build_form(submitted_params(:order))

        if @form.save(employee: current_employee)
          redirect_to pos_location_additional_orders_path(@location),
                      notice: t(".success", count: @form.created_count)
        else
          flash.now[:alert] = @form.errors.full_messages.first
          render :new, status: :unprocessable_entity
        end
      end

      private

      def redirect_unless_inventories
        return if @location.has_today_inventory?

        redirect_to new_pos_location_daily_inventory_path(@location)
      end

      def set_inventories
        @inventories = @location.today_inventories
                                .eager_load(:catalog)
                                .merge(Catalog.where(category: :bento))
                                .order("catalogs.kana")
      end

      def set_additional_orders
        @additional_orders = @location.additional_orders
                                      .where(order_at: Date.current.all_day)
                                      .eager_load(:catalog)
                                      .order(order_at: :desc)
      end

      def current_employee
        return nil unless rodauth(:employee).logged_in?

        Employee.find_by(id: rodauth(:employee).session_value)
      end
    end
  end
end
