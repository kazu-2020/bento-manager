# frozen_string_literal: true

module Catalogs
  module DiscontinueForm
    class Component < Application::Component
      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      def form_url
        helpers.catalog_discontinuation_path(catalog)
      end

      def modal_title
        I18n.t("catalogs.discontinuations.modal_title")
      end
    end
  end
end
