# frozen_string_literal: true

Rails.application.config.view_component.tap do |config|
  # コンポーネント配置先
  config.view_component_path = Rails.root.join("app/views/components")

  # ジェネレータ設定
  config.generate.sidecar = true
  config.generate.preview = true
  config.generate.stimulus_controller = true
  config.generate.locale = true
end
