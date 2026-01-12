# frozen_string_literal: true

require "test_helper"

class Locations::LocationListComponentTest < ViewComponent::TestCase
  def setup
    @location1 = Location.new(id: 1, name: "市役所", status: :active)
    @location2 = Location.new(id: 2, name: "県庁", status: :active)
  end

  def test_renders_grid_with_locations
    result = render_inline(Locations::LocationList::Component.new(locations: [ @location1, @location2 ]))

    assert result.css(".grid").present?
    assert_includes result.to_html, @location1.name
    assert_includes result.to_html, @location2.name
  end

  def test_renders_empty_state_when_no_locations
    result = render_inline(Locations::LocationList::Component.new(locations: []))

    assert_not result.css(".grid").present?
    assert_includes result.to_html, "販売先が登録されていません"
  end

  def test_renders_location_cards_for_each_location
    result = render_inline(Locations::LocationList::Component.new(locations: [ @location1, @location2 ]))

    assert_equal 2, result.css(".card").count
  end

  def test_grid_has_responsive_columns
    result = render_inline(Locations::LocationList::Component.new(locations: [ @location1 ]))

    grid = result.css(".grid").first
    assert_includes grid["class"], "grid-cols-1"
    assert_includes grid["class"], "md:grid-cols-2"
    assert_includes grid["class"], "lg:grid-cols-3"
  end

  def test_empty_state_has_icon
    result = render_inline(Locations::LocationList::Component.new(locations: []))

    assert result.css("svg").present?
  end
end
