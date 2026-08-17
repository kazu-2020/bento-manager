# frozen_string_literal: true

module Discounts
  module NewForm
    class Component < Application::Component
      FORM_ID = "new_discount"
      MODAL_FRAME_ID = "discount_new_modal"
      # キャンセルボタンの所有者にする <form method="dialog"> の id
      MODAL_CLOSE_FORM_ID = "discount_new_modal_close"

      # close_form_id は必須。省略を許すと、閉じるフォームの無い場所で描画されたときに
      # キャンセルが何も起きないボタンになって無言で壊れる
      def initialize(discount:, close_form_id:)
        @discount = discount
        @close_form_id = close_form_id
      end

      attr_reader :discount, :close_form_id

      def modal_title
        I18n.t("discounts.new.title")
      end

      def coupon
        discount.discountable
      end
    end
  end
end
