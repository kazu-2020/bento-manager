# frozen_string_literal: true

require "test_helper"

module Locations
  class StatusBadgeComponentTest < ViewComponent::TestCase
    def test_renders_active_badge
      result = render_inline(Locations::StatusBadge::Component.new(status: :active))

      assert_predicate result.css(".badge.badge-success.badge-soft"), :present?
      assert_includes result.to_html, "取引中"
    end

    def test_renders_inactive_badge
      result = render_inline(Locations::StatusBadge::Component.new(status: :inactive))

      assert_predicate result.css(".badge.badge-error.badge-soft"), :present?
      assert_includes result.to_html, "取引停止"
    end

    def test_accepts_string_status
      result = render_inline(Locations::StatusBadge::Component.new(status: "active"))

      assert_predicate result.css(".badge.badge-success"), :present?
    end
  end
end
