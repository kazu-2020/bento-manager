require "test_helper"

# CSP を `script-src 'self'` + nonce で運用しているため、
# インラインイベントハンドラも nonce のない <script> もブラウザに無視される。
# 追加された時点でテストが落ちるようにして、実行時にだけ壊れる状態を防ぐ。
class InlineJavascriptTest < ActiveSupport::TestCase
  # HTML 属性記法（onclick="…"）。属性名は on + 英字なので構造だけでは "only" 等と区別できず、
  # 素朴に `:` まで許すと Ruby のオプション記法に誤爆する。記法ごとに分けて見る。
  INLINE_EVENT_HANDLER = /\son[a-z]+\s*=\s*["']/

  # Rails ヘルパーのオプション記法（link_to …, onclick: "…"）。
  # レンダリング結果は onclick="…" になるので CSP に無視される。
  # ここだけはイベント名を列挙して "only:" のような同形の語との誤検知を避ける。
  EVENT_NAMES = %w[
    click dblclick change input submit reset focus blur keydown keyup keypress
    mousedown mouseup mouseover mouseout mouseenter mouseleave
    touchstart touchend load error toggle select scroll
  ].freeze
  INLINE_EVENT_OPTION = /\bon(?:#{Regexp.union(EVENT_NAMES).source})\s*:\s*["']/

  # src も nonce も持たない <script> だけを禁止する（nonce 付きは CSP 上正当）。
  # 属性名の先頭を空白で固定する: \b だと data-src= の "-" 直後にも境界ができてしまう。
  SCRIPT_TAG_WITHOUT_SRC = /<script(?![^>]*\s(?:src|nonce)[\s=])/

  test "ビューにインラインイベントハンドラを書かない" do
    assert_empty offending_views(Regexp.union(INLINE_EVENT_HANDLER, INLINE_EVENT_OPTION)),
                 "onclick 等は属性でもヘルパーのオプションでも書かず、Stimulus コントローラに置き換える"
  end

  test "ビューにインラインスクリプトを書かない" do
    assert_empty offending_views(SCRIPT_TAG_WITHOUT_SRC),
                 "<script> の中身は Vite のエントリポイントに移す"
  end

  private

  def offending_views(pattern)
    Dir[Rails.root.join("app/views/**/*.erb")].select do |path|
      File.read(path).match?(pattern)
    end.map { |path| Pathname.new(path).relative_path_from(Rails.root).to_s }
  end
end
