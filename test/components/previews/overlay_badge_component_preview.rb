# frozen_string_literal: true

class OverlayBadgeComponentPreview < ViewComponent::Preview
  # @label バッジあり
  def overlaid
    render_with_template
  end

  # @label バッジなし
  def plain
    render_with_template
  end
end
