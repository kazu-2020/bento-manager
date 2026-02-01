# frozen_string_literal: true

require "test_helper"

class Locations::ShowComponentTest < ViewComponent::TestCase
  def setup
    @active_location = Location.new(
      id: 1,
      name: "市役所",
      status: :active,
      created_at: Time.zone.now,
      updated_at: Time.zone.now
    )
    @inactive_location = Location.new(
      id: 2,
      name: "県庁",
      status: :inactive,
      created_at: Time.zone.now,
      updated_at: Time.zone.now
    )
  end

  def test_renders_location_name_in_header
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert result.css("h1").present?
    assert_includes result.to_html, @active_location.name
  end

  def test_renders_status_badge
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert result.css(".badge").present?
  end

  def test_renders_edit_link
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    # 編集リンクは基本情報セクション内にあり、edit へのリンク（Turbo Frame で処理）
    edit_link = result.css("a[href='/locations/1/edit']").first
    assert edit_link.present?
    assert_includes edit_link["class"], "btn"
    assert_includes edit_link["class"], "btn-ghost"
  end

  def test_renders_back_link_at_top
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    back_link = result.css("nav a[href='/locations']").first
    assert back_link.present?
    assert_includes result.to_html, "販売先一覧へ戻る"
  end

  def test_renders_basic_info_card
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert result.css(".card").present?
    assert result.css(".card-body").present?
  end

  def test_inactive_location_has_opacity
    result = render_inline(Locations::Show::Component.new(location: @inactive_location))

    card = result.css("section.card").first
    assert_includes card["class"], "opacity-75"
  end

  def test_renders_future_sections_with_empty_states
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert_includes result.to_html, "販売履歴"
    assert_includes result.to_html, "在庫状況"
  end

  def test_has_accessible_section_headings
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert result.css("section[aria-labelledby='basic-info-heading']").present?
    assert result.css("section[aria-labelledby='sales-history-heading']").present?
    assert result.css("section[aria-labelledby='inventory-heading']").present?
  end

  def test_renders_location_icon_in_header
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert result.css("header .icon").present?
  end

  def test_renders_created_at_and_updated_at
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert_includes result.to_html, "登録日時"
    assert_includes result.to_html, "更新日時"
  end

  def test_renders_empty_states_for_related_data
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert_includes result.to_html, "販売履歴はありません"
    assert_includes result.to_html, "在庫情報はありません"
  end
end
