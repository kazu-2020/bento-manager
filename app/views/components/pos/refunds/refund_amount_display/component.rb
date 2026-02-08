# frozen_string_literal: true

module Pos
  module Refunds
    module RefundAmountDisplay
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :has_any_changes?, :preview_adjustment_amount, :adjustment_type, to: :form

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

        def title_key
          case adjustment_type
          when :refund then ".title_refund"
          when :additional_charge then ".title_additional_charge"
          else ".title_even_exchange"
          end
        end
      end
    end
  end
end
