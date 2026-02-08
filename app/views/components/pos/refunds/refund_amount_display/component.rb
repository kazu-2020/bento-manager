# frozen_string_literal: true

module Pos
  module Refunds
    module RefundAmountDisplay
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :has_any_changes?, :preview_adjustment_amount, :adjustment_type,
                 :preview_price_result, to: :form

        def formatted_amount
          helpers.number_to_currency(preview_adjustment_amount.abs)
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

        def discount_details
          @discount_details ||= preview_price_result&.dig(:discount_details) || []
        end

        def returned_coupons
          discount_details
            .select { |d| d[:requested_quantity].to_i > d[:quantity].to_i }
            .map do |d|
              {
                name: d[:discount_name],
                quantity: d[:requested_quantity].to_i - d[:quantity].to_i
              }
            end
        end

        def any_returned_coupons?
          returned_coupons.any?
        end
      end
    end
  end
end
