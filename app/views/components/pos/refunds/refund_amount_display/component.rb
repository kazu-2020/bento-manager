# frozen_string_literal: true

module Pos
  module Refunds
    module RefundAmountDisplay
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :has_any_changes?, to: :form
        delegate :preview, to: :form, private: true
        delegate :adjustment_type, :adjustment_amount, :returned_discounts, to: :preview

        def formatted_amount
          helpers.number_to_currency(adjustment_amount.abs)
        end

        def card_class
          case adjustment_type
          when :refund then "bg-error text-white"
          when :additional_charge then "bg-info text-white"
          else "bg-success text-white"
          end
        end

        def amount_label_key
          case adjustment_type
          when :refund then ".amount_refund"
          when :additional_charge then ".amount_additional_charge"
          else ".amount_even_exchange"
          end
        end

        # 返却枚数の算出は Preview が元の販売と突き合わせて持つ
        def any_returned_coupons?
          returned_discounts.any?
        end
      end
    end
  end
end
