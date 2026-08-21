# frozen_string_literal: true

# メインフォームと Ghost Form の input 名の対応を、実 ERB をレンダリングして検査する。
#
# ghost_form_controller.js は FormData の各キーに ghost_ を付けた input を
# querySelector で探し、見つからなければ黙って値を捨てる。両者の名前は別々の ERB
# リテラルで決まるため、片方をリネームしても例外もテスト失敗も出ない。
#
# Ghost Form を持つ画面には、この形のテストを 1 本置くこと。
#
#   include GhostFormCorrespondenceHelper
#
#   result = render_inline(Pos::Sales::NewForm::Component.new(...))
#   assert_ghost_inputs_correspond(result, minimum: 3)
module GhostFormCorrespondenceHelper
  # 送信ボタンはブラウザが FormData に載せず、残る 2 つは
  # ghost_form_controller.js が転写前に明示的に取り除く
  NON_TRANSCRIBED_NAMES = %w[_method authenticity_token].freeze
  NON_TRANSCRIBED_TYPES = %w[submit button].freeze

  # @param minimum [Integer] 母集合の下限。空のまま素通りして緑になるのを防ぐ
  def assert_ghost_inputs_correspond(result, minimum: 1)
    originals = original_field_names(result)
    ghosts = ghost_field_names(result)

    assert_operator originals.size, :>=, minimum,
                    "メインフォームの入力が想定より少ない。母集合が痩せると検査が素通りする"

    missing = originals.reject { |name| ghosts.include?("ghost_#{name}") }

    assert_empty missing, "Ghost Form に対応する input が無い: #{missing.join(', ')}"
  end

  private

  # FormData が拾うのは input だけではないので select / textarea も母集合に入れる
  def original_field_names(result)
    fields_in(result, "originalForm", "input, select, textarea")
      .reject { |field| field["type"].in?(NON_TRANSCRIBED_TYPES) }
      .filter_map { |field| field["name"] }
      .reject { |name| name.in?(NON_TRANSCRIBED_NAMES) }
      .uniq
  end

  # 受け皿は必ず hidden input（ghost_form_controller.js が input しか探さない）
  def ghost_field_names(result)
    fields_in(result, "ghostForm", "input").filter_map { |field| field["name"] }.to_set
  end

  def fields_in(result, target, selectors)
    scope = %([data-ghost-form-target="#{target}"])

    result.css(selectors.split(", ").map { |sel| "#{scope} #{sel}" }.join(", "))
  end
end
