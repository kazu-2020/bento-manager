# frozen_string_literal: true

module Pos
  module Refunds
    module RefundCouponCard
      class Component < Application::Component
        with_collection_parameter :discount

        def initialize(discount:, form:)
          @discount = discount
          @form = form
        end

        attr_reader :discount, :form

        def dom_id
          "refund-coupon-card-#{discount.id}"
        end

        def card_classes
          class_names(
            "card bg-base-100 border-2 transition-all duration-200",
            "border-accent bg-accent/10": !disabled? && in_cart?,
            "border-base-300": disabled? || !in_cart?,
            "opacity-50": disabled? || max_quantity <= 0
          )
        end

        def disabled?
          form.total_corrected_bento_quantity <= 0
        end

        def in_cart?
          current_quantity > 0
        end

        def current_quantity
          form.coupon_quantities[discount.id] || 0
        end

        def max_quantity
          coupon = discount.discountable
          return 0 unless coupon.respond_to?(:max_applicable_quantity)

          cart_items = form.corrected_items_for_refunder
          coupon.max_applicable_quantity(cart_items)
        end

        def effective_max
          disabled? ? 0 : max_quantity
        end

        def coupon_field_name
          "refund[coupon][#{discount.id}][quantity]"
        end

        def discount_amount_display
          coupon = discount.discountable
          return nil unless coupon.respond_to?(:amount_per_unit)

          helpers.number_to_currency(coupon.amount_per_unit)
        end
      end
    end
  end
end
