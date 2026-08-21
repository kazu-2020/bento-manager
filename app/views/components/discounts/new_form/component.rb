# frozen_string_literal: true

module Discounts
  module NewForm
    class Component < Application::Component
      FORM_ID = "new_discount"

      def initialize(discount:)
        @discount = discount
      end

      attr_reader :discount

      def modal_title
        I18n.t("discounts.new.title")
      end

      def coupon
        discount.discountable
      end
    end
  end
end
