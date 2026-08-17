# frozen_string_literal: true

module Discounts
  module NewForm
    class Component < Application::Component
      FORM_ID = "new_discount"
      MODAL_FRAME_ID = "discount_new_modal"
      # キャンセルボタンの所有者にする <form method="dialog"> の id
      MODAL_CLOSE_FORM_ID = "discount_new_modal_close"

      def initialize(discount:)
        @discount = discount
      end

      attr_reader :discount

      def close_form_id
        MODAL_CLOSE_FORM_ID
      end

      def modal_title
        I18n.t("discounts.new.title")
      end

      def coupon
        discount.discountable
      end
    end
  end
end
