# frozen_string_literal: true

module Catalogs
  module CategorySelector
    class Component < Application::Component
      CARD_BASE_CLASSES = "card border-2 cursor-pointer transition-all hover:shadow-md hover:scale-[1.02]"

      def initialize(selected: nil)
        @selected = selected
      end

      attr_reader :selected

      def categories
        [
          {
            key: "bento",
            name: I18n.t("enums.catalog.category.bento"),
            icon: "bento",
            description: I18n.t("catalogs.new.category.bento.description")
          },
          {
            key: "side_menu",
            name: I18n.t("enums.catalog.category.side_menu"),
            icon: "side_dish",
            description: I18n.t("catalogs.new.category.side_menu.description")
          }
        ]
      end

      def card_classes(category_key)
        helpers.class_names(
          CARD_BASE_CLASSES,
          "border-primary bg-primary/10" => selected == category_key,
          "border-base-300 bg-base-100" => selected != category_key
        )
      end

      def selected?(category_key)
        selected == category_key
      end

      def new_with_category_path(category_key)
        helpers.new_catalog_path(category: category_key)
      end
    end
  end
end
