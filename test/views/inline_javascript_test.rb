require "test_helper"

# CSP を `script-src 'self'` + nonce で運用しているため、
# インラインイベントハンドラも nonce のない <script> もブラウザに無視される。
# 追加された時点でテストが落ちるようにして、実行時にだけ壊れる状態を防ぐ。
class InlineJavascriptTest < ActiveSupport::TestCase
  INLINE_EVENT_HANDLER = /\son[a-z]+\s*=\s*["']/
  # src も nonce も持たない <script> だけを禁止する（nonce 付きは CSP 上正当）
  SCRIPT_TAG_WITHOUT_SRC = /<script(?![^>]*\b(?:src|nonce)[\s=])/

  test "ビューにインラインイベントハンドラを書かない" do
    assert_empty offending_views(INLINE_EVENT_HANDLER),
                 "onclick 等の属性は Stimulus コントローラに置き換える"
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
