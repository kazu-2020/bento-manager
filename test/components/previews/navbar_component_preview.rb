# frozen_string_literal: true

class NavbarComponentPreview < ViewComponent::Preview
  def default
    render(Navbar::Component.new)
  end

  # @param drawer_id text
  def with_custom_drawer_id(drawer_id: "custom-drawer")
    render(Navbar::Component.new(drawer_id: drawer_id))
  end
end
