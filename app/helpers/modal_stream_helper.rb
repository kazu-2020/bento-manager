# frozen_string_literal: true

module ModalStreamHelper
  def modal_stream_show(&block)
    turbo_stream_action_tag("show_modal", template: capture(&block))
  end
end
