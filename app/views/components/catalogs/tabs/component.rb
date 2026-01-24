# frozen_string_literal: true

module Catalogs
  module Tabs
    class Component < Application::Component
      def self.categories
        Catalog.categories.keys.map(&:to_sym)
      end

      def initialize(current_category:)
        @current_category = current_category&.to_sym || :bento
      end

      attr_reader :current_category

      def tabs
        self.class.categories.map do |category|
          {
            key: category,
            label: I18n.t("enums.catalog.category.#{category}"),
            path: helpers.catalogs_path(category: category),
            active: current_category == category
          }
        end
      end

      def tab_class(active:)
        helpers.class_names(
          "tab",
          "tab-active" => active
        )
      end
    end
  end
end
