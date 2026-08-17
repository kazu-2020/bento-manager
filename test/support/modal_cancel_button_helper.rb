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
    main_form = Nokogiri::HTML5.fragment(html).at_css(form_selector)

    assert main_form, "メインフォームが描画されていること (#{form_selector})"

    # form 属性を持つボタンは所有者が別フォームなので、このフォームの送信ボタンではない
    submitters = main_form
                   .css("button[type='submit'], button:not([type]), input[type='submit']")
                   .reject { |button| button["form"] }

    assert_equal submit_buttons, submitters.size,
                 "メインフォームの送信ボタンは #{submit_buttons} 個だけにする" \
                 "（キャンセルが混ざると Enter が「閉じる」に化ける）"

    cancel = main_form.at_css("button[form]")

    assert cancel, "キャンセルボタンが form= で別フォームに紐付いていること"

    # ダイアログ内の method=dialog フォームならどれでも閉じるので、これを見ないと
    # モーダル固有のフォームを指していても素通りする。閉じるフォームは 1 つに集約する
    assert_equal ModalStreamHelper::MODAL_CLOSE_FORM_ID, cancel["form"],
                 "キャンセルは共有の閉じるフォームを参照すること"

    # 紐付け先は同じ <dialog> の中で探す。ダイアログの外にあるフォームを参照しても閉じない
    dialog = main_form.ancestors.find { |node| node.name == "dialog" }

    assert dialog, "メインフォームが <dialog> の中に描画されていること"

    close_form = dialog.at_css("form##{cancel['form']}")

    assert close_form, "紐付け先のフォームが同じダイアログ内にあること"
    assert_equal "dialog", close_form["method"], "紐付け先は method=dialog でなければ閉じない"
  end

  # ターボフレームだけを差し替える再描画（バリデーションエラー時など）でキャンセルが
  # 死なないことを保証する。閉じるフォームがフレームの中にあると、差し替えで消えてしまい
  # キャンセルの form= が宙に浮く。
  def assert_close_form_survives_frame_replacement(html, frame_id:, close_form_id:)
    fragment = Nokogiri::HTML5.fragment(html)

    assert fragment.at_css("form##{close_form_id}"), "閉じるフォームが描画されていること"

    frame = fragment.at_css("turbo-frame##{frame_id}")

    assert frame, "ターボフレームが描画されていること (#{frame_id})"
    assert_empty frame.css("form##{close_form_id}"),
                 "閉じるフォームをフレームの中に置くと、フレームだけ差し替えたときに消えて" \
                 "キャンセルの form= が宙に浮く"
  end

  # フレームだけ差し替えたレスポンス（<dialog> も閉じるフォームも含まれない）向け。
  # 再描画されたキャンセルが、DOM に残っている閉じるフォームを指し続けていることを見る。
  def assert_cancel_bound_to_close_form(html, close_form_id:)
    cancel = Nokogiri::HTML5.fragment(html).at_css("button[form='#{close_form_id}']")

    assert cancel, "再描画されたキャンセルも form=#{close_form_id} を指していること"
  end
end
