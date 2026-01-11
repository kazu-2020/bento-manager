# frozen_string_literal: true

class NavbarComponentPreview < ViewComponent::Preview
  # @!group Default

  # デフォルトのナビゲーションバー
  def default
    render(NavbarComponent.new)
  end

  # @!endgroup

  # @!group Variations

  # カスタム drawer ID
  # @param drawer_id text "ドロワーの ID"
  def with_custom_drawer_id(drawer_id: "custom-drawer")
    render(NavbarComponent.new(drawer_id: drawer_id))
  end

  # @!endgroup
end
