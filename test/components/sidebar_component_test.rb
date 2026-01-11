# frozen_string_literal: true

require "test_helper"

class SidebarComponentTest < ViewComponent::TestCase
  def test_renders_sidebar
    result = render_inline(SidebarComponent.new(current_path: "/"))

    assert result.css("aside").present?
    assert_includes result.to_html, "Bento Manager"
  end

  def test_renders_all_menu_items
    result = render_inline(SidebarComponent.new(current_path: "/"))

    assert_includes result.to_html, "ホーム"
    assert_includes result.to_html, "従業員"
    assert_includes result.to_html, "配達場所"
    assert_includes result.to_html, "カタログ"
  end

  def test_highlights_active_home
    result = render_inline(SidebarComponent.new(current_path: "/"))

    active_link = result.css("a.active")
    assert active_link.present?
    assert_includes active_link.to_html, "ホーム"
  end

  def test_highlights_active_employees
    result = render_inline(SidebarComponent.new(current_path: "/admin/employees"))

    active_link = result.css("a.active")
    assert active_link.present?
    assert_includes active_link.to_html, "従業員"
  end

  def test_highlights_active_employees_subpage
    result = render_inline(SidebarComponent.new(current_path: "/admin/employees/1/edit"))

    active_link = result.css("a.active")
    assert active_link.present?
    assert_includes active_link.to_html, "従業員"
  end

  def test_highlights_active_locations
    result = render_inline(SidebarComponent.new(current_path: "/locations"))

    active_link = result.css("a.active")
    assert active_link.present?
    assert_includes active_link.to_html, "配達場所"
  end

  def test_highlights_active_catalogs
    result = render_inline(SidebarComponent.new(current_path: "/catalogs/new"))

    active_link = result.css("a.active")
    assert active_link.present?
    assert_includes active_link.to_html, "カタログ"
  end

  def test_renders_menu_icons
    result = render_inline(SidebarComponent.new(current_path: "/"))

    # 4つのメニュー項目それぞれにアイコン
    assert result.css("svg").count >= 4
  end

  def test_renders_footer_with_copyright
    result = render_inline(SidebarComponent.new(current_path: "/"))

    assert_includes result.to_html, Date.current.year.to_s
    assert_includes result.to_html, "Bento Manager"
  end
end
