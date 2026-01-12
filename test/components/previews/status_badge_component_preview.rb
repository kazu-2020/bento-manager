# frozen_string_literal: true

class StatusBadgeComponentPreview < ViewComponent::Preview
  # @label 有効
  def active
    render(StatusBadge::Component.new(status: :active))
  end

  # @label 無効
  def inactive
    render(StatusBadge::Component.new(status: :inactive))
  end

  # @param status select { choices: [active, inactive] }
  # @param model select { choices: [location, employee] }
  def with_params(status: :active, model: :location)
    render(StatusBadge::Component.new(status: status.to_sym, model: model.to_sym))
  end
end
