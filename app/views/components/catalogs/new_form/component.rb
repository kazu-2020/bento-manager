# frozen_string_literal: true

module Catalogs
  module NewForm
    class Component < Application::Component
      FORM_FIELDS_FRAME_ID = "catalog_form_fields"
      CATEGORY_SELECTOR_SECTION_ID = "catalog_category_selector_section"
      CATEGORY_HIDDEN_ID = "catalog_category_hidden"
      MODAL_ACTIONS_ID = "catalog_modal_actions"

      def initialize(creator: nil, selected_category: nil)
        @creator = creator
        @selected_category = selected_category
      end

      attr_reader :creator, :selected_category

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

      def form_fields_frame_id
        FORM_FIELDS_FRAME_ID
      end
    end
  end
end
