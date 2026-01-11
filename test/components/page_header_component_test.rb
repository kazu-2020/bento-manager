# frozen_string_literal: true

require "test_helper"

class PageHeaderComponentTest < ViewComponent::TestCase
  def test_renders_title
    result = render_inline(PageHeaderComponent.new(title: "テストタイトル"))

    assert result.css("h1").present?
    assert_includes result.to_html, "テストタイトル"
  end

  def test_renders_new_button_when_path_provided
    result = render_inline(PageHeaderComponent.new(title: "テスト", new_path: "/test/new"))

    assert result.css("a.btn.btn-neutral").present?
    assert_includes result.to_html, "新規登録"
  end

  def test_hides_new_button_when_path_not_provided
    result = render_inline(PageHeaderComponent.new(title: "テスト"))

    assert result.css("a.btn").blank?
  end

  def test_renders_custom_new_label
    result = render_inline(PageHeaderComponent.new(
      title: "テスト",
      new_path: "/test/new",
      new_label: "追加する"
    ))

    assert_includes result.to_html, "追加する"
  end

  def test_renders_plus_icon
    result = render_inline(PageHeaderComponent.new(title: "テスト", new_path: "/test/new"))

    assert result.css("svg").present?
  end
end
