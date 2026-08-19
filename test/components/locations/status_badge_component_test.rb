# frozen_string_literal: true

require "test_helper"

module Locations
  class StatusBadgeComponentTest < ViewComponent::TestCase
    test "販売先の取引状態を色付きバッジで表示する" do
      active = render_inline(Locations::StatusBadge::Component.new(status: :active))

      assert_predicate active.css(".badge.badge-success.badge-soft"), :present?
      assert_includes active.to_html, "取引中"

      inactive = render_inline(Locations::StatusBadge::Component.new(status: :inactive))

      assert_predicate inactive.css(".badge.badge-error.badge-soft"), :present?
      assert_includes inactive.to_html, "取引停止"

      from_string = render_inline(Locations::StatusBadge::Component.new(status: "active"))

      assert_predicate from_string.css(".badge.badge-success"), :present?
    end
  end
end
