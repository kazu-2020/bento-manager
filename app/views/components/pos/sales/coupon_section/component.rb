# frozen_string_literal: true

module Pos
  module Sales
    module CouponSection
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :discounts, :total_bento_quantity, to: :form

        def has_discounts?
          discounts.any?
        end

        def coupon_quantity(discount)
          form.coupon_quantity(discount)
        end

        def max_coupon_quantity(discount)
          coupon = discount.discountable
          return 0 unless coupon.respond_to?(:max_applicable_quantity)

          cart_items = form.cart_items_for_calculator
          coupon.max_applicable_quantity(cart_items)
        end

        def coupon_disabled?(discount)
          total_bento_quantity <= 0
        end

        def discount_amount_display(discount)
          coupon = discount.discountable
          return nil unless coupon.respond_to?(:amount_per_unit)

          helpers.number_to_currency(coupon.amount_per_unit)
        end
      end
    end
  end
end
