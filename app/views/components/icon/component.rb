# frozen_string_literal: true

module Icon
  class Component < Application::Component
    SIZES = {
      xs: "h-3 w-3",
      sm: "h-4 w-4",
      md: "h-5 w-5",
      lg: "h-6 w-6",
      xl: "h-8 w-8"
    }.freeze

    def initialize(name:, size: :md, extra_class: nil)
      @name = name
      @size = size.to_sym
      @extra_class = extra_class
    end

    private

    attr_reader :name, :size, :extra_class

    def css_classes
      ["icon", size_class, extra_class].compact.join(" ")
    end

    def size_class
      SIZES.fetch(size, SIZES[:md])
    end

    def icon_url
      helpers.vite_asset_path("images/icons/#{name}.svg")
    end
  end
end
