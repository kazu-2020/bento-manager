# frozen_string_literal: true

module Pos
  module SalesHistory
    module SaleItemCard
      class Component < Application::Component
        def initialize(sale:, location:)
          @sale = sale
          @location = location
        end

        attr_reader :sale, :location

        delegate :items, :voided?, :sale_discounts, to: :sale

        def sale_time
          I18n.l(sale.sale_datetime, format: :short)
        end

        def formatted_amount
          helpers.number_to_currency(sale.final_amount)
        end

        def customer_type_badge_class
          case sale.customer_type
          when "staff"
            "badge-accent"
          else
            "badge-neutral"
          end
        end

        def customer_type_label
          I18n.t("enums.sale.customer_type.#{sale.customer_type}")
        end

        def refund_url
          helpers.new_pos_location_refund_path(location, sale_id: sale.id)
        end

        def has_discounts?
          sale_discounts.present?
        end

        def formatted_discounts_summary
          total = sale_discounts.sum { |sd| sd.quantity * sd.discount.coupon.amount_per_unit }
          helpers.number_to_currency(-total)
        end

        def employee_name
          sale.employee&.username || "-"
        end
      end
    end
  end
end
