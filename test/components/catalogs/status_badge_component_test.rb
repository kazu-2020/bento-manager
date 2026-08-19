# frozen_string_literal: true

require "test_helper"

module Catalogs
  class StatusBadgeComponentTest < ViewComponent::TestCase
    fixtures :catalogs

    test "商品カタログの提供状態を色付きバッジで表示する" do
      available = render_inline(Catalogs::StatusBadge::Component.new(catalog: catalogs(:daily_bento_a)))

      assert_predicate available.css(".badge.badge-success.badge-soft"), :present?
      assert_includes available.to_html, "販売中"

      discontinued = render_inline(Catalogs::StatusBadge::Component.new(catalog: discontinued_catalog))

      assert_predicate discontinued.css(".badge.badge-error.badge-soft"), :present?
      assert_includes discontinued.to_html, "提供終了"
    end

    private

    def discontinued_catalog
      catalogs(:discontinued_bento).tap do |catalog|
        catalog.create_discontinuation!(discontinued_at: Time.current, reason: "テスト用提供終了")
      end
    end
  end
end
