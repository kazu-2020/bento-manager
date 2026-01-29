# frozen_string_literal: true

module Pos
  module Locations
    class RefundsController < ApplicationController
      before_action :set_location
      before_action :set_sale, only: [ :new, :create ]
      before_action :redirect_if_voided, only: :new

      def new
        @form = build_form
      end

      def create
        @form = build_form(submitted_params(:refund).merge("_submitting" => "true"))

        unless @form.valid?
          flash.now[:alert] = t(".missing_requirements")
          return render :new, status: :unprocessable_entity
        end

        refunder = ::Sales::Refunder.new
        result = refunder.process(
          sale: @sale,
          remaining_items: @form.remaining_items_for_refunder,
          reason: @form.reason,
          employee: current_employee
        )

        redirect_to pos_location_sales_history_index_path(@location),
                    notice: t(".success", amount: helpers.number_to_currency(result[:refund_amount]))
      rescue Sale::AlreadyVoidedError
        flash.now[:alert] = t(".already_voided")
        render :new, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        flash.now[:alert] = e.record.errors.full_messages.first
        render :new, status: :unprocessable_entity
      end

      private

      def set_location
        @location = Location.active.find(params[:location_id])
      end

      def set_sale
        @sale = @location.sales
                         .preload(items: :catalog)
                         .find(params[:sale_id])
      end

      def redirect_if_voided
        return unless @sale.voided?

        redirect_to pos_location_sales_history_index_path(@location),
                    alert: t("pos.locations.refunds.create.already_voided")
      end

      def build_form(submitted = {})
        ::Refunds::RefundForm.new(
          sale: @sale,
          location: @location,
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
