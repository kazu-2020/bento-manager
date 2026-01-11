# frozen_string_literal: true

class SidebarComponentPreview < ViewComponent::Preview
  def home_active
    render(Sidebar::Component.new(current_path: "/"))
  end

  def employees_active
    render(Sidebar::Component.new(current_path: "/admin/employees"))
  end

  def locations_active
    render(Sidebar::Component.new(current_path: "/locations"))
  end

  def catalogs_active
    render(Sidebar::Component.new(current_path: "/catalogs"))
  end

  # @param current_path text
  def with_custom_path(current_path: "/")
    render(Sidebar::Component.new(current_path: current_path))
  end
end
