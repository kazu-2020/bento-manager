# frozen_string_literal: true

module Catalogs
  module BasicInfo
    class Component < Application::Component
      FRAME_ID = "catalog_basic_info_frame"
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      delegate :name, :category, :description, :discontinued?, to: :catalog

      def frame_id
        FRAME_ID
      end

      def edit_path
        helpers.edit_catalog_path(catalog)
      end

      def card_classes
        helpers.class_names(CARD_CLASSES, "opacity-75" => discontinued?)
      end

      def category_label
        I18n.t("enums.catalog.category.#{category}")
      end

      def category_icon
        category == "bento" ? "bento" : "side_dish"
      end

      def created_at_formatted
        helpers.l(catalog.created_at, format: :long) if catalog.created_at
      end

      def updated_at_formatted
        helpers.l(catalog.updated_at, format: :long) if catalog.updated_at
      end
    end
  end
end
