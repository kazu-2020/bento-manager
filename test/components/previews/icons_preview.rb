# frozen_string_literal: true

class IconsPreview < ViewComponent::Preview
  ICON_NAMES = %w[plus close success error home menu users location catalog].freeze

  # @label 全アイコン一覧
  def all_icons
    render_with_template
  end

  # @label サイズ比較
  def sizes
    render_with_template
  end
end
