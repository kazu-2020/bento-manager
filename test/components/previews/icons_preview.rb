# frozen_string_literal: true

class IconsPreview < ViewComponent::Preview
  ICONS_DIR = Rails.root.join("app/frontend/images/icons")

  # 手書きの列挙だと実ファイルとずれるため、SVG のファイル名から導出する
  def self.icon_names
    ICONS_DIR.glob("*.svg").map { |path| path.basename(".svg").to_s }.sort
  end

  # @label 全アイコン一覧
  def all_icons
    render_with_template
  end

  # @label サイズ比較
  def sizes
    render_with_template
  end
end
