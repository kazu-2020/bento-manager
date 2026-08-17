# frozen_string_literal: true

module Catalogs
  module NewForm
    class Component < Application::Component
      FORM_ID = "new_catalog"
      MODAL_FRAME_ID = "catalog_new_modal"
      FORM_FIELDS_FRAME_ID = "catalog_form_fields"
      # キャンセルボタンの所有者にする <form method="dialog"> の id
      MODAL_CLOSE_FORM_ID = "catalog_new_modal_close"

      def initialize(creator: nil, selected_category: nil)
        @creator = creator
        @selected_category = selected_category
      end

      attr_reader :creator, :selected_category

      def close_form_id
        MODAL_CLOSE_FORM_ID
      end

      def category_selected?
        selected_category.present?
      end

      def bento_selected?
        selected_category == "bento"
      end

      def side_menu_selected?
        selected_category == "side_menu"
      end

      def modal_title
        return I18n.t("catalogs.new.title") unless category_selected?

        I18n.t("catalogs.new.#{selected_category}_title")
      end
    end
  end
end
