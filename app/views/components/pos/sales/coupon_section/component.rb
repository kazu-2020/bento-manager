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

        def coupon_card_classes(discount)
          disabled = coupon_disabled?(discount)
          in_cart = coupon_quantity(discount) > 0

          helpers.class_names(
            "card bg-base-100 border-2 transition-all duration-200",
            "border-accent bg-accent/10": !disabled && in_cart,
            "border-base-300": disabled || !in_cart,
            "opacity-50": disabled || max_coupon_quantity(discount) <= 0
          )
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
