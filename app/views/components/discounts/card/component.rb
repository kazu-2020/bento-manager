# frozen_string_literal: true

module Discounts
  module Card
    class Component < Application::Component
      with_collection_parameter :discount

      BASE_CARD_CLASSES = "card bg-base-100 shadow-sm border border-base-300 w-full"

      def initialize(discount:)
        @discount = discount
      end

      attr_reader :discount

      delegate :name, :valid_from, :valid_until, to: :discount

      def show_path
        helpers.discount_path(discount)
      end

      def card_classes
        helpers.class_names(
          BASE_CARD_CLASSES,
          "opacity-50" => expired?,
          "hover:shadow-md hover:border-base-content/20 transition-all duration-200" => !expired?
        )
      end

      def coupon
        discount.discountable
      end

      def amount_per_unit
        coupon&.amount_per_unit
      end

      def max_per_bento_quantity
        coupon&.max_per_bento_quantity
      end

      def formatted_amount
        helpers.number_to_currency(amount_per_unit) if amount_per_unit
      end

      def status
        return :expired if expired?
        return :upcoming if upcoming?

        :active
      end

      def status_badge_class
        case status
        when :active then "badge-success"
        when :expired then "badge-error"
        when :upcoming then "badge-warning"
        end
      end

      def formatted_valid_period
        from = helpers.l(valid_from, format: :short)
        to = valid_until ? helpers.l(valid_until, format: :short) : t(".no_end_date")
        "#{from} 〜 #{to}"
      end

      private

      def expired?
        valid_until.present? && valid_until < Date.current
      end

      def upcoming?
        valid_from > Date.current
      end
    end
  end
end
