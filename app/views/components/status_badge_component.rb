# frozen_string_literal: true

class StatusBadgeComponent < ApplicationComponent
  VARIANTS = {
    active: "badge-success",
    inactive: "badge-error badge-outline"
  }.freeze

  def initialize(status:, model: :location)
    @status = status.to_sym
    @model = model
  end

  def variant_class
    VARIANTS.fetch(@status, "badge-ghost")
  end

  def label
    I18n.t("enums.#{@model}.status.#{@status}")
  end
end
