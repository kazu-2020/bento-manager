# frozen_string_literal: true

require "test_helper"

module Discounts
  class StatusBadgeComponentTest < ViewComponent::TestCase
    test "割引の適用期間の状態を色付きバッジで表示する" do
      active = render_inline(Discounts::StatusBadge::Component.new(status: :active))

      assert_predicate active.css(".badge.badge-success.badge-soft"), :present?
      assert_includes active.to_html, "有効"

      expired = render_inline(Discounts::StatusBadge::Component.new(status: :expired))

      assert_predicate expired.css(".badge.badge-error.badge-soft"), :present?
      assert_includes expired.to_html, "期限切れ"

      upcoming = render_inline(Discounts::StatusBadge::Component.new(status: :upcoming))

      assert_predicate upcoming.css(".badge.badge-warning.badge-soft"), :present?
      assert_includes upcoming.to_html, "期間前"
    end
  end
end
