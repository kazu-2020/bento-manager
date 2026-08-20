# frozen_string_literal: true

require "test_helper"

# 1 操作に「300ms のデバウンス + POST + ERB のレンダリング + Turbo の適用」が乗るため、
# Capybara 既定の 2 秒では CI の遅いランナーで足りない
Capybara.default_max_wait_time = 5

# 数量の増減ボタンはアイコンだけで、識別子は aria-label しか無い
Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # ここで parallelize を呼んではいけない（Minitest.parallel_executor を
  # グローバルに差し替える実装のため、単体テスト全体まで直列化する）。
  # 理由と代わりの手当ては .claude/rules/testing.md のルール8 を参照。

  # パスワードマネージャーは必ず切ったままにする。切らないと Chrome の保存バブルが
  # 合成マウス入力を飲み、2 回目以降のクリックだけが無言で効かなくなる
  # （.claude/rules/testing.md のルール8「踏み抜きやすい罠」）。
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
  end

  include SystemLoginHelper
end
