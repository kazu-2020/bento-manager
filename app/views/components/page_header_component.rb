# frozen_string_literal: true

class PageHeaderComponent < ApplicationComponent
  def initialize(title:, new_path: nil, new_label: nil)
    @title = title
    @new_path = new_path
    @new_label = new_label || I18n.t("helpers.link.new")
  end

  attr_reader :title, :new_path, :new_label

  def new_button?
    new_path.present?
  end
end
