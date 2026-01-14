# frozen_string_literal: true

module ToastStreamHelper
  DEFAULT_DURATION_MS = 5000

  # トーストを表示するTurbo Streamアクションを生成
  def toast_stream_show(message, type: :success, duration: DEFAULT_DURATION_MS)
    turbo_stream_action_tag(
      "show_toast",
      template: render(Toast::Component.new(message: message, type: type)),
      duration: duration
    )
  end
end
