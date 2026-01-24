# frozen_string_literal: true

module Catalogs
  module BasicInfoForm
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      delegate :discontinued?, to: :catalog

      def frame_id
        Catalogs::BasicInfo::Component::FRAME_ID
      end

      def catalog_path
        helpers.catalog_path(catalog)
      end

      def card_classes
        helpers.class_names(CARD_CLASSES, "opacity-75" => discontinued?)
      end
    end
  end
end
