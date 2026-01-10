# frozen_string_literal: true

Rails.application.config.view_component.tap do |config|
  # sidecar構造で生成（example/component.rb, component.html.erb）
  config.generate.sidecar = true

  # プレビューも同時生成
  config.generate.preview = true

  # Stimulus連携用（既存のVite + Stimulus構成に合わせる）
  config.generate.stimulus_controller = true

  # i18n翻訳ファイル生成
  config.generate.locale = true
end
