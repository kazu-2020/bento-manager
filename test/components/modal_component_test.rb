# frozen_string_literal: true

require "test_helper"

class ModalComponentTest < ViewComponent::TestCase
  BODY_MARKUP = '<form id="body_form"><input name="name"></form>'

  def test_wraps_content_in_a_dialog_box
    result = render_modal

    assert_predicate result.css("dialog.modal > .modal-box"), :present?
    assert_predicate result.css("dialog.modal > .modal-box > form#body_form"), :present?
  end

  # 閉じるフォームがダイアログの外にあるとキャンセルの form= が閉じない
  def test_renders_the_shared_close_form_inside_the_box
    close_form = render_modal.at_css("dialog.modal > .modal-box > form##{ModalStreamHelper::MODAL_CLOSE_FORM_ID}")

    assert close_form, "閉じるフォームが modal-box の中にあること"
    assert_equal "dialog", close_form["method"], "method=dialog でなければ閉じない"
  end

  # 閉じるボタンは本体より前に置く。後ろに回すと Tab の最初が入力欄になり、
  # 5 画面で挙動が割れる
  def test_close_form_precedes_the_content
    children = render_modal.css("dialog.modal > .modal-box > *")

    assert_equal ModalStreamHelper::MODAL_CLOSE_FORM_ID, children.first["id"]
    assert_equal "body_form", children.last["id"]
  end

  # backdrop は modal-box の外。中に入れると本体をクリックしただけで閉じる
  def test_renders_the_backdrop_outside_the_box
    result = render_modal
    backdrop = result.at_css("dialog.modal > form.modal-backdrop")

    assert backdrop, "backdrop が dialog の直下にあること"
    assert_equal "dialog", backdrop["method"]
    assert_empty result.css(".modal-box form.modal-backdrop"),
                 "backdrop を modal-box の中に置くと本体のクリックで閉じる"
  end

  # 幅は daisyUI 既定の 32rem に揃える。画面ごとに max-w-* を足さない
  def test_does_not_constrain_the_box_width
    box = render_modal.at_css(".modal-box")

    assert_not box["class"].split.any? { |name| name.start_with?("max-w-") },
               "modal-box に max-w-* を付けないこと（既定の 32rem に揃える）"
  end

  private

  def render_modal
    render_inline(Modal::Component.new) { BODY_MARKUP.html_safe }
  end
end
