# frozen_string_literal: true

module Catalogs
  module Tabs
    class Component < Application::Component
      CATEGORIES = %i[bento side_menu].freeze

      def initialize(current_category:)
        @current_category = current_category&.to_sym || :bento
      end

      attr_reader :current_category

      def tabs
        CATEGORIES.map do |category|
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
