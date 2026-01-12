# frozen_string_literal: true

require "test_helper"

class LocationCardComponentTest < ViewComponent::TestCase
  def setup
    @active_location = Location.new(id: 1, name: "市役所", status: :active)
    @inactive_location = Location.new(id: 2, name: "県庁", status: :inactive)
  end

  def test_renders_location_name
    result = render_inline(LocationCard::Component.new(location: @active_location))

    assert_includes result.to_html, @active_location.name
  end

  def test_active_location_does_not_render_badge
    result = render_inline(LocationCard::Component.new(location: @active_location))

    assert_not result.css(".badge").present?
  end

  def test_inactive_location_renders_status_badge
    result = render_inline(LocationCard::Component.new(location: @inactive_location))

    assert result.css(".badge.badge-soft.badge-error").present?
    assert_includes result.to_html, "取引停止"
  end

  def test_card_is_clickable_link
    result = render_inline(LocationCard::Component.new(location: @active_location))

    link = result.css("a.card").first
    assert link.present?
    assert_equal "/locations/1", link["href"]
  end

  def test_renders_card_structure
    result = render_inline(LocationCard::Component.new(location: @active_location))

    assert result.css(".card").present?
    assert result.css(".card-body").present?
    assert result.css(".card-title").present?
  end

  def test_card_has_hover_effect
    result = render_inline(LocationCard::Component.new(location: @active_location))

    link = result.css("a.card").first
    assert_includes link["class"], "hover:shadow-md"
  end
end
