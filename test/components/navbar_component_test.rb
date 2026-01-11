# frozen_string_literal: true

require "test_helper"

class NavbarComponentTest < ViewComponent::TestCase
  def test_renders_navbar
    result = render_inline(NavbarComponent.new)

    assert result.css(".navbar").present?
    assert_includes result.to_html, "Bento Manager"
  end

  def test_renders_mobile_menu_toggle
    result = render_inline(NavbarComponent.new)

    assert result.css("label[for='main-drawer']").present?
    assert result.css("svg").present? # ハンバーガーアイコン
  end

  def test_renders_user_menu
    result = render_inline(NavbarComponent.new)

    assert result.css(".dropdown").present?
    assert_includes result.to_html, "プロフィール"
    assert_includes result.to_html, "設定"
    assert_includes result.to_html, "ログアウト"
  end

  def test_uses_custom_drawer_id
    result = render_inline(NavbarComponent.new(drawer_id: "custom-drawer"))

    assert result.css("label[for='custom-drawer']").present?
  end
end
