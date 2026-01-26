# frozen_string_literal: true

module Sidebar
  class Component < Application::Component
    MenuItem = Data.define(:path, :label, :icon, :path_prefix) do
      def home?
        path_prefix.nil?
      end
    end

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

    private

    attr_reader :current_path

    def menu_items
      @menu_items ||= [
        MenuItem.new(path: helpers.root_path, label: "ホーム", icon: :home, path_prefix: nil),
        MenuItem.new(path: helpers.pos_locations_path, label: "POS", icon: :bento, path_prefix: "/pos"),
        MenuItem.new(path: helpers.admin_employees_path, label: "従業員", icon: :users, path_prefix: "/admin/employees"),
        MenuItem.new(path: helpers.locations_path, label: "配達場所", icon: :location, path_prefix: "/locations"),
        MenuItem.new(path: helpers.catalogs_path, label: "カタログ", icon: :catalog, path_prefix: "/catalogs"),
        MenuItem.new(path: helpers.discounts_path, label: "クーポン", icon: :ticket, path_prefix: "/discounts")
      ]
    end
  end
end
