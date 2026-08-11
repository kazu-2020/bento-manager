# frozen_string_literal: true

class StatusIndicatorComponentPreview < ViewComponent::Preview
  # @label バッジあり
  def flagged
    render(StatusIndicator::Component.new(flagged: true, label: "提供終了")) do
      tag.div("カード本体", class: "card bg-base-100 shadow-sm border border-base-300 w-full p-8")
    end
  end

  # @label バッジなし
  def unflagged
    render(StatusIndicator::Component.new(flagged: false, label: "提供終了")) do
      tag.div("カード本体", class: "card bg-base-100 shadow-sm border border-base-300 w-full p-8")
    end
  end
end
