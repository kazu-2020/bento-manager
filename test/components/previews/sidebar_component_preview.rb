# frozen_string_literal: true

class SidebarComponentPreview < ViewComponent::Preview
  # @!group Active States

  # ホームがアクティブ
  def home_active
    render(SidebarComponent.new(current_path: "/"))
  end

  # 従業員がアクティブ
  def employees_active
    render(SidebarComponent.new(current_path: "/admin/employees"))
  end

  # 配達場所がアクティブ
  def locations_active
    render(SidebarComponent.new(current_path: "/locations"))
  end

  # カタログがアクティブ
  def catalogs_active
    render(SidebarComponent.new(current_path: "/catalogs"))
  end

  # @!endgroup

  # @!group Interactive

  # カスタムパスでプレビュー
  # @param current_path text "現在のパス"
  def with_custom_path(current_path: "/")
    render(SidebarComponent.new(current_path: current_path))
  end

  # @!endgroup
end
