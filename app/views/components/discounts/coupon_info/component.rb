# frozen_string_literal: true

module Discounts
  module CouponInfo
    class Component < Application::Component
      FRAME_ID = "discount_coupon_info_frame"
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(discount:)
        @discount = discount
      end

      attr_reader :discount

      def frame_id
        FRAME_ID
      end

      def card_classes
        CARD_CLASSES
      end

      def coupon
        discount.discountable
      end

      def formatted_amount
        helpers.number_to_currency(coupon&.amount_per_unit) if coupon&.amount_per_unit
      end
    end
  end
end
