# frozen_string_literal: true

module Catalogs
  module PriceForm
    class Component < Application::Component
      MODAL_FRAME_ID = "catalog_price_form_modal_frame"
      # キャンセルボタンの所有者にする <form method="dialog"> の id。
      # 閉じるフォームはフレームの外にあるので、フレームだけ差し替える再描画でも DOM に残る
      MODAL_CLOSE_FORM_ID = "catalog_price_modal_close"

      def initialize(catalog:, catalog_price:, kind:)
        @catalog = catalog
        @catalog_price = catalog_price
        @kind = kind.to_s
      end

      attr_reader :catalog, :catalog_price, :kind

      def frame_id
        MODAL_FRAME_ID
      end

      def close_form_id
        MODAL_CLOSE_FORM_ID
      end

      def form_url
        helpers.catalog_catalog_price_path(catalog, kind)
      end

      def modal_title
        if catalog_price.persisted?
          I18n.t("catalog_prices.edit.title", kind: kind_label)
        else
          I18n.t("catalog_prices.new.title", kind: kind_label)
        end
      end

      def kind_label
        I18n.t("enums.catalog_price.kind.#{kind}")
      end
    end
  end
end
