# frozen_string_literal: true

Rails.application.config.view_component.tap do |config|
  config.view_component_path = Rails.root.join("app/views/components")
  config.generate.sidecar = true
  config.generate.preview = true
  config.generate.stimulus_controller = true
  config.generate.locale = true
  config.previews.default_layout = "component_preview"
end
