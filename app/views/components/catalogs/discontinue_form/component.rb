# frozen_string_literal: true

module Catalogs
  module DiscontinueForm
    class Component < Application::Component
      MODAL_FRAME_ID = "catalog_discontinue_form_modal_frame"
      # キャンセルボタンの所有者にする <form method="dialog"> の id
      MODAL_CLOSE_FORM_ID = "catalog_discontinue_modal_close"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      def frame_id
        MODAL_FRAME_ID
      end

      def close_form_id
        MODAL_CLOSE_FORM_ID
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
