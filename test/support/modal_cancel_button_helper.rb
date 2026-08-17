# frozen_string_literal: true

# モーダルのキャンセルボタンは form= でダイアログを閉じる <form method="dialog"> に
# 所有者を移す。メインフォームの送信ボタンのままだと tree order 上いちばん先頭になり、
# HTML 仕様でいう default button（暗黙送信の対象）を奪ってしまう。その状態でテキスト欄で
# Enter を押すと「保存」ではなくキャンセルが送信され、入力が失われる。
module ModalCancelButtonHelper
  # @param html [String] モーダルを描画したレスポンスボディ
  # @param form_selector [String] メインフォームを指す CSS セレクタ
  # @param submit_buttons [Integer] メインフォームが持つべき送信ボタンの数
  def assert_modal_cancel_uses_close_form(html, form_selector:, submit_buttons: 1)
    fragment = Nokogiri::HTML5.fragment(html)
    main_form = fragment.css(form_selector).first

    assert main_form, "メインフォームが描画されていること (#{form_selector})"

    # form 属性を持つボタンは所有者が別フォームなので、このフォームの送信ボタンではない
    submitters = main_form
                   .css("button[type='submit'], button:not([type]), input[type='submit']")
                   .reject { |button| button["form"] }

    assert_equal submit_buttons, submitters.size,
                 "メインフォームの送信ボタンは #{submit_buttons} 個だけにする" \
                 "（キャンセルが混ざると Enter が「閉じる」に化ける）"

    cancel = main_form.css("button[form]").first

    assert cancel, "キャンセルボタンが form= で別フォームに紐付いていること"

    close_form = fragment.css("form##{cancel['form']}").first

    assert close_form, "紐付け先のフォームが同じダイアログ内にあること"
    assert_equal "dialog", close_form["method"], "紐付け先は method=dialog でなければ閉じない"
  end
end

class ActionDispatch::IntegrationTest
  include ModalCancelButtonHelper
end
