# frozen_string_literal: true

require "test_helper"

class OverlayBadgeComponentTest < ViewComponent::TestCase
  CARD_MARKUP = '<a class="card" href="/catalogs/1">本体</a>'
  BADGE_MARKUP = '<span class="badge badge-error badge-soft">提供終了</span>'

  def test_overlaid_wraps_content_with_the_given_badge
    result = render_overlay(overlaid: true)

    assert_predicate result.css(".indicator > .indicator-item > .badge"), :present?
    assert_includes result.to_html, "提供終了"
    assert_predicate result.css(".indicator > a.card"), :present?
    assert_includes result.css(".indicator-item").first["class"], "indicator-center"
    assert_includes result.css(".indicator-item").first["class"], "indicator-middle"
  end

  def test_not_overlaid_renders_content_without_wrapper
    result = render_overlay(overlaid: false)

    assert_not result.css(".indicator").present?
    assert_not result.css(".badge").present?
    assert_not_includes result.to_html, "提供終了"
    assert_predicate result.css("a.card"), :present?
  end

  def test_badge_does_not_swallow_clicks_on_the_card
    overlay = render_overlay(overlaid: true).css(".indicator-item").first

    assert_includes overlay["class"], "pointer-events-none"
  end

  private

  def render_overlay(overlaid:)
    render_inline(OverlayBadge::Component.new(overlaid: overlaid)) do |component|
      component.with_badge { BADGE_MARKUP.html_safe }
      CARD_MARKUP.html_safe
    end
  end
end
