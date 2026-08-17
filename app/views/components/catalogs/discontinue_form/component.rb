# frozen_string_literal: true

module Catalogs
  module DiscontinueForm
    class Component < Application::Component
      MODAL_FRAME_ID = "catalog_discontinue_form_modal_frame"
      # キャンセルボタンの所有者にする <form method="dialog"> の id
      MODAL_CLOSE_FORM_ID = "catalog_discontinue_modal_close"

      # close_form_id は必須。省略を許すと、閉じるフォームの無い場所で描画されたときに
      # キャンセルが何も起きないボタンになって無言で壊れる
      def initialize(catalog:, close_form_id:)
        @catalog = catalog
        @close_form_id = close_form_id
      end

      attr_reader :catalog, :close_form_id

      def frame_id
        MODAL_FRAME_ID
      end

      def form_url
        helpers.catalog_discontinuation_path(catalog)
      end

      def modal_title
        I18n.t("catalogs.discontinuations.modal_title")
      end
    end
  end
end
