# frozen_string_literal: true

require "test_helper"

class StatusBadgeComponentTest < ViewComponent::TestCase
  def test_renders_active_badge
    result = render_inline(StatusBadgeComponent.new(status: :active))

    assert result.css(".badge.badge-success").present?
    assert_includes result.to_html, "有効"
  end

  def test_renders_inactive_badge
    result = render_inline(StatusBadgeComponent.new(status: :inactive))

    assert result.css(".badge.badge-error").present?
    assert_includes result.to_html, "無効"
  end

  def test_accepts_string_status
    result = render_inline(StatusBadgeComponent.new(status: "active"))

    assert result.css(".badge.badge-success").present?
  end

  def test_renders_with_custom_model
    result = render_inline(StatusBadgeComponent.new(status: :active, model: :location))

    assert_includes result.to_html, "有効"
  end
end
