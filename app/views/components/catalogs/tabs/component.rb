# frozen_string_literal: true

module Catalogs
  module Tabs
    class Component < Application::Component
      CATEGORIES = %i[all bento side_menu].freeze

      def initialize(current_category:)
        @current_category = current_category&.to_sym
      end

      attr_reader :current_category

      def tabs
        CATEGORIES.map do |category|
          {
            key: category,
            label: tab_label(category),
            path: tab_path(category),
            active: active?(category)
          }
        end
      end

      def tab_class(active:)
        helpers.class_names(
          "tab",
          "tab-active" => active
        )
      end

      private

      def tab_label(category)
        case category
        when :all then I18n.t("helpers.filter.all")
        else I18n.t("enums.catalog.category.#{category}")
        end
      end

      def tab_path(category)
        case category
        when :all then helpers.catalogs_path
        else helpers.catalogs_path(category: category)
        end
      end

      def active?(category)
        category == :all ? current_category.nil? : current_category == category
      end
    end
  end
end
