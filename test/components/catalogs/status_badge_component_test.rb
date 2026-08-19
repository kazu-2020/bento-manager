# frozen_string_literal: true

require "test_helper"

module Catalogs
  class StatusBadgeComponentTest < ViewComponent::TestCase
    test "商品カタログの提供状態を色付きバッジで表示する" do
      available = render_inline(Catalogs::StatusBadge::Component.new(status: :available))

      assert_predicate available.css(".badge.badge-success.badge-soft"), :present?
      assert_includes available.to_html, "販売中"

      discontinued = render_inline(Catalogs::StatusBadge::Component.new(status: :discontinued))

      assert_predicate discontinued.css(".badge.badge-error.badge-soft"), :present?
      assert_includes discontinued.to_html, "提供終了"
    end
  end
end
