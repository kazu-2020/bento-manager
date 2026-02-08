# frozen_string_literal: true

module Pos
  module Locations
    class RefundsController < ApplicationController
      include RefundFormBuildable

      before_action :set_location
      before_action :set_sale, only: [ :new, :create ]
      before_action :set_inventories, only: [ :new, :create ]
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
          corrected_items: @form.corrected_items_for_refunder,
          employee: current_employee,
          discount_quantities: @form.discount_quantities_for_refunder
        )

        amount = result[:refund_amount]
        notice = if amount.positive?
                   t(".success_refund", amount: helpers.number_to_currency(amount))
        elsif amount.negative?
                   t(".success_additional_charge", amount: helpers.number_to_currency(amount.abs))
        else
                   t(".success_even_exchange")
        end

        redirect_to pos_location_sales_history_index_path(@location), notice: notice
      rescue Sale::AlreadyVoidedError
        flash.now[:alert] = t(".already_voided")
        render :new, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        flash.now[:alert] = e.record.errors.full_messages.first
        render :new, status: :unprocessable_entity
      end

      private

      def redirect_if_voided
        return unless @sale.voided?

        redirect_to pos_location_sales_history_index_path(@location),
                    alert: t("pos.locations.refunds.create.already_voided")
      end

      def current_employee
        return nil unless rodauth(:employee).logged_in?

        Employee.find_by(id: rodauth(:employee).session_value)
      end
    end
  end
end
