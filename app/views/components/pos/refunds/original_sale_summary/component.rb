# frozen_string_literal: true

module Pos
  module Refunds
    module OriginalSaleSummary
      class Component < Application::Component
        def initialize(sale:)
          @sale = sale
        end

        attr_reader :sale

        delegate :items, to: :sale

        def sale_datetime
          I18n.l(sale.sale_datetime, format: :datetime)
        end

        def customer_type_label
          I18n.t("enums.sale.customer_type.#{sale.customer_type}")
        end

        def customer_type_badge_class
          case sale.customer_type
          when "staff"
            "badge-accent"
          else
            "badge-neutral"
          end
        end

        def formatted_final_amount
          helpers.number_to_currency(sale.final_amount)
        end

        def has_discounts?
          sale.total_amount != sale.final_amount
        end

        def formatted_discount_amount
          helpers.number_to_currency(sale.final_amount - sale.total_amount)
        end
      end
    end
  end
end
