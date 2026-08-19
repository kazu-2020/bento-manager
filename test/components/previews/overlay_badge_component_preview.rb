# frozen_string_literal: true

class OverlayBadgeComponentPreview < ViewComponent::Preview
  # @label バッジあり
  def overlaid
    render_with_template(template: "overlay_badge_component_preview/preview", locals: { overlaid: true })
  end

  # @label バッジなし
  def plain
    render_with_template(template: "overlay_badge_component_preview/preview", locals: { overlaid: false })
  end
end
