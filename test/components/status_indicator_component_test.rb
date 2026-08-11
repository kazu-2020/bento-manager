# frozen_string_literal: true

require "test_helper"

class StatusIndicatorComponentTest < ViewComponent::TestCase
  CARD_MARKUP = '<a class="card" href="/catalogs/1">本体</a>'

  def test_flagged_wraps_content_with_badge
    result = render_indicator(flagged: true)

    assert_predicate result.css(".indicator > .badge.badge-error.badge-soft"), :present?
    assert_includes result.to_html, "提供終了"
    assert_predicate result.css(".indicator > a.card"), :present?
  end

  def test_unflagged_renders_content_without_wrapper
    result = render_indicator(flagged: false)

    assert_not result.css(".indicator").present?
    assert_not result.css(".badge").present?
    assert_not_includes result.to_html, "提供終了"
    assert_predicate result.css("a.card"), :present?
  end

  def test_badge_does_not_swallow_clicks_on_the_card
    badge = render_indicator(flagged: true).css(".badge").first

    assert_includes badge["class"], "pointer-events-none"
    assert_equal "span", badge.name
  end

  private

  def render_indicator(flagged:, label: "提供終了")
    render_inline(StatusIndicator::Component.new(flagged: flagged, label: label)) do
      CARD_MARKUP.html_safe
    end
  end
end
