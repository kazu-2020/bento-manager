# frozen_string_literal: true

module Pos
  module Refunds
    module SubmitButton
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :has_any_changes?, :adjustment_type, to: :form

        def disabled?
          !has_any_changes?
        end

        def button_class
          base = "btn text-white w-full"
          case adjustment_type
          when :additional_charge then "#{base} btn-info"
          when :even_exchange then "#{base} btn-success"
          else "#{base} btn-error"
          end
        end

        def submit_label
          case adjustment_type
          when :additional_charge then t(".submit_additional_charge")
          when :even_exchange then t(".submit_even_exchange")
          else t(".submit_refund")
          end
        end
      end
    end
  end
end
