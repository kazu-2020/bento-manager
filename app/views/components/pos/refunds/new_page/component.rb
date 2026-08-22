# frozen_string_literal: true

module Pos
  module Refunds
    module NewPage
      class Component < Application::Component
        def initialize(form:, sale:, location:)
          @form = form
          @sale = sale
          @location = location
        end

        attr_reader :form, :sale, :location

        delegate :form_with_options,
                 :bento_corrected_items, :side_menu_corrected_items,
                 :available_discounts, to: :form

        # 中身が 1 つも無いタブは並べない。修正カートに弁当が無ければ弁当タブも出ない
        def tab_items
          @tab_items ||= begin
            items = []
            items << { key: :bento, label: I18n.t("enums.catalog.category.bento") } if bento_corrected_items.any?
            items << { key: :side_menu, label: I18n.t("enums.catalog.category.side_menu") } if side_menu_corrected_items.any?
            items << { key: :coupon, label: I18n.t("enums.catalog.category.coupon") } if available_discounts.any?
            items
          end
        end
      end
    end
  end
end
