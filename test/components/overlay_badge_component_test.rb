# frozen_string_literal: true

require "test_helper"

class OverlayBadgeComponentTest < ViewComponent::TestCase
  CARD_MARKUP = '<a class="card" href="/catalogs/1">本体</a>'
  BADGE_MARKUP = '<span class="badge badge-error badge-soft">提供終了</span>'

  def test_wraps_content_when_a_badge_is_given
    result = render_overlay(with_badge: true)

    assert_predicate result.css(".indicator > .indicator-item > .badge"), :present?
    assert_includes result.to_html, "提供終了"
    assert_predicate result.css(".indicator > a.card"), :present?
    assert_includes result.css(".indicator-item").first["class"], "indicator-center"
    assert_includes result.css(".indicator-item").first["class"], "indicator-middle"
  end

  def test_renders_content_without_wrapper_when_no_badge_is_given
    result = render_overlay(with_badge: false)

    assert_not result.css(".indicator").present?
    assert_not result.css(".badge").present?
    assert_predicate result.css("a.card"), :present?
  end

  def test_badge_does_not_swallow_clicks_on_the_card
    overlay = render_overlay(with_badge: true).css(".indicator-item").first

    assert_includes overlay["class"], "pointer-events-none"
  end

  private

  def render_overlay(with_badge:)
    render_inline(OverlayBadge::Component.new) do |component|
      component.with_badge { BADGE_MARKUP.html_safe } if with_badge
      CARD_MARKUP.html_safe
    end
  end
end
