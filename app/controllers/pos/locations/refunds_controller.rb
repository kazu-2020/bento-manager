# frozen_string_literal: true

module Pos
  module Locations
    class RefundsController < ApplicationController
      include RefundFormBuildable

      def new
        @form = build_form
      end

      def create
        @form = build_form(submitted_params(:refund, form: ::Refunds::RefundForm))

        unless @form.valid?
          # 差し戻す理由はフォームが持っている。壊れた送信と「変更なし」では
          # 案内すべき内容が違うため、固定文ではなく実際のエラーを出す
          flash.now[:alert] = @form.errors.full_messages.first
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
      # ガードは set_sale が読んだ時点の値しか見ていない。二重確定は先に精算した
      # 側が行を書き換え、日付が変わる瞬間の送信は Refunder と別々に時計を読む。
      # どちらもガードをすり抜けてここへ来るため、同じリダイレクトへ寄せる
      rescue Sale::AlreadyVoidedError
        redirect_to_sales_history("pos.locations.refunds.already_voided")
      rescue Sale::NotTodaysSaleError
        redirect_to_sales_history("pos.locations.refunds.not_todays_sale")
      rescue ActiveRecord::RecordInvalid => e
        flash.now[:alert] = e.record.errors.full_messages.first
        render :new, status: :unprocessable_entity
      end
    end
  end
end
