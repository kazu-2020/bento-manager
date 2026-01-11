# frozen_string_literal: true

module Sidebar
  class Component < Application::Component
    MenuItem = Data.define(:path, :label, :icon, :path_prefix) do
      def home?
        path_prefix.nil?
      end
    end

    ICONS = {
      home: '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>',
      users: '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>',
      location: '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>',
      catalog: '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" /></svg>'
    }.freeze

    def initialize(current_path:)
      @current_path = current_path
    end

    def home_item
      menu_items.find(&:home?)
    end

    def admin_items
      menu_items.reject(&:home?)
    end

    def active?(item)
      return current_path == item.path unless item.path_prefix

      current_path.start_with?(item.path_prefix)
    end

    def menu_item_class(item)
      base = "flex items-center gap-3"
      active?(item) ? "#{base} active bg-primary/10 text-primary font-medium" : "#{base} hover:bg-base-300"
    end

    def render_icon(icon_name)
      ICONS[icon_name]&.html_safe
    end

    private

    attr_reader :current_path

    def menu_items
      @menu_items ||= [
        MenuItem.new(path: helpers.root_path, label: "ホーム", icon: :home, path_prefix: nil),
        MenuItem.new(path: helpers.admin_employees_path, label: "従業員", icon: :users, path_prefix: "/admin/employees"),
        MenuItem.new(path: helpers.locations_path, label: "配達場所", icon: :location, path_prefix: "/locations"),
        MenuItem.new(path: helpers.catalogs_path, label: "カタログ", icon: :catalog, path_prefix: "/catalogs")
      ]
    end
  end
end
