# frozen_string_literal: true

require "test_helper"

module Discounts
  class StatusBadgeComponentTest < ViewComponent::TestCase
    def test_renders_active_badge
      result = render_inline(Discounts::StatusBadge::Component.new(status: :active))

      assert_predicate result.css(".badge.badge-success.badge-soft"), :present?
      assert_includes result.to_html, "有効"
    end

    def test_renders_expired_badge
      result = render_inline(Discounts::StatusBadge::Component.new(status: :expired))

      assert_predicate result.css(".badge.badge-error.badge-soft"), :present?
      assert_includes result.to_html, "期限切れ"
    end

    def test_renders_upcoming_badge
      result = render_inline(Discounts::StatusBadge::Component.new(status: :upcoming))

      assert_predicate result.css(".badge.badge-warning.badge-soft"), :present?
      assert_includes result.to_html, "期間前"
    end
  end
end
