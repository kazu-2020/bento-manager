# frozen_string_literal: true

module ModalStreamHelper
  # ダイアログを閉じる <form method="dialog"> の id。
  #
  # モーダルのキャンセルボタンは、この id を form= で指して所有者をそのフォームに移す。
  # メインフォームの送信ボタンのままだと tree order 上いちばん先頭になり、HTML 仕様でいう
  # default button（暗黙送信の対象）を奪う。その状態でテキスト欄で Enter を押すと
  # 「保存」ではなくキャンセルが送信され、入力が失われる。
  #
  # show_modal は container.replaceChildren で描画するので、開いているモーダルは常に 1 つ。
  # モーダルごとに id を分ける必要はない。
  MODAL_CLOSE_FORM_ID = "modal_close"

  # モーダルを開く唯一の入口。殻（modal-box / 閉じるフォーム / backdrop）は
  # Modal::Component が出すので、呼び出し側は中身だけを渡す。
  # 見出しは殻に含めず shared/_modal_title で呼び出し側が置く（理由は
  # .claude/rules/modal-structure.md のルール 2）。
  def modal_stream_show(&block)
    turbo_stream_action_tag("show_modal", template: render(Modal::Component.new, &block))
  end

  def modal_close_form_id
    MODAL_CLOSE_FORM_ID
  end
end
