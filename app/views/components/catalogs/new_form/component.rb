# frozen_string_literal: true

module Catalogs
  module NewForm
    class Component < Application::Component
      FORM_FIELDS_FRAME_ID = "catalog_form_fields"

      def initialize(errors: nil, selected_category: nil)
        @errors = errors
        @selected_category = selected_category
      end

      attr_reader :errors, :selected_category

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
