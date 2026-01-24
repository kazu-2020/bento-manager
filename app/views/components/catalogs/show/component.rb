# frozen_string_literal: true

module Catalogs
  module Show
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      delegate :name, :category, :discontinued?, to: :catalog

      def back_path
        helpers.catalogs_path
      end

      def category_icon
        category == "bento" ? "bento" : "side_dish"
      end
    end
  end
end
