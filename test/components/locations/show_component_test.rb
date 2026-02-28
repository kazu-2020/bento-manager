# frozen_string_literal: true

require "test_helper"

class Locations::ShowComponentTest < ViewComponent::TestCase
  include SaleTestHelper

  fixtures :locations, :employees, :catalogs, :catalog_prices

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

  def test_renders_sales_history_section
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert_includes result.to_html, "販売履歴"
  end

  def test_has_accessible_section_headings
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert result.css("section[aria-labelledby='basic-info-heading']").present?
    assert result.css("section[aria-labelledby='sales-history-heading']").present?
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

  def test_renders_empty_state_when_no_sales_history
    result = render_inline(Locations::Show::Component.new(location: @active_location))

    assert_includes result.to_html, "販売履歴はありません"
  end

  def test_renders_chart_when_sales_history_exists
    location = locations(:city_hall)
    create_sale(location:, customer_type: :staff, sale_datetime: 3.days.ago)

    result = render_inline(Locations::Show::Component.new(location:))

    assert result.css("[id^='chart-']").present?
    assert_not_includes result.to_html, "販売履歴はありません"
  end
end
