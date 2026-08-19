# frozen_string_literal: true

module Locations
  class StatusBadgeComponentPreview < ViewComponent::Preview
    # @label 取引中
    def active
      render(Locations::StatusBadge::Component.new(status: :active))
    end

    # @label 取引停止
    def inactive
      render(Locations::StatusBadge::Component.new(status: :inactive))
    end

    # @param status select { choices: [active, inactive] }
    def with_params(status: :active)
      render(Locations::StatusBadge::Component.new(status: status.to_sym))
    end
  end
end
