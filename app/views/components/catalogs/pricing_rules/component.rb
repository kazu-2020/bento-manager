# frozen_string_literal: true

module Catalogs
  module PricingRules
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(catalog:)
        @catalog = catalog
      end

      attr_reader :catalog

      delegate :discontinued?, to: :catalog

      def card_classes
        helpers.class_names(CARD_CLASSES, "opacity-75" => discontinued?)
      end

      def pricing_rules
        @pricing_rules ||= catalog.active_pricing_rules
      end

      def has_rules?
        pricing_rules.any?
      end

      def price_kind_label(rule)
        I18n.t("enums.catalog_pricing_rule.price_kind.#{rule.price_kind}")
      end

      def trigger_category_label(rule)
        I18n.t("enums.catalog_pricing_rule.trigger_category.#{rule.trigger_category}")
      end

      def valid_period(rule)
        from = helpers.l(rule.valid_from, format: :short)
        if rule.valid_until.present?
          to = helpers.l(rule.valid_until, format: :short)
          "#{from} 〜 #{to}"
        else
          "#{from} 〜"
        end
      end
    end
  end
end
