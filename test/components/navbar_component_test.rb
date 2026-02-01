# frozen_string_literal: true

require "test_helper"

class NavbarComponentTest < ViewComponent::TestCase
  def test_renders_navbar
    result = render_inline(Navbar::Component.new)

    assert result.css(".navbar").present?
  end

  def test_renders_mobile_menu_toggle
    result = render_inline(Navbar::Component.new)

    assert result.css("label[for='main-drawer']").present?
    assert result.css("svg").present?
  end

  def test_renders_app_title
    result = render_inline(Navbar::Component.new)

    assert_includes result.to_html, "弁当販売管理"
  end

  def test_hides_logout_menu_when_not_logged_in
    result = render_inline(Navbar::Component.new)

    # ログインしていない場合はログアウトメニューが表示されない
    assert_not result.css(".dropdown").present?
  end

  def test_uses_custom_drawer_id
    result = render_inline(Navbar::Component.new(drawer_id: "custom-drawer"))

    assert result.css("label[for='custom-drawer']").present?
  end
end
