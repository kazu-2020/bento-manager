# frozen_string_literal: true

require "test_helper"

module Catalogs
  class StatusBadgeComponentTest < ViewComponent::TestCase
    def test_renders_available_badge_for_a_live_catalog
      result = render_inline(Catalogs::StatusBadge::Component.new(catalog: available_catalog))

      assert_predicate result.css(".badge.badge-success.badge-soft"), :present?
      assert_includes result.to_html, "販売中"
    end

    def test_renders_discontinued_badge_for_a_discontinued_catalog
      result = render_inline(Catalogs::StatusBadge::Component.new(catalog: discontinued_catalog))

      assert_predicate result.css(".badge.badge-error.badge-soft"), :present?
      assert_includes result.to_html, "提供終了"
    end

    private

    def available_catalog
      Catalog.new(name: "日替わり弁当A", kana: "ヒガワリベントウエー", category: :bento)
    end

    def discontinued_catalog
      available_catalog.tap(&:build_discontinuation)
    end
  end
end
