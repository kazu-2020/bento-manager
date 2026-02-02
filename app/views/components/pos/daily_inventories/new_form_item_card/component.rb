# frozen_string_literal: true

module Pos
  module DailyInventories
    module NewFormItemCard
      class Component < Application::Component
        def initialize(item:, hidden: false)
          @item = item
          @hidden = hidden
        end

        attr_reader :item

        delegate :catalog_id, :catalog_name, :selected?, :stock, to: :item

        def hidden?
          @hidden
        end

        def dom_id
          "item-card-#{catalog_id}"
        end

        def item_field_name
          "inventory[#{catalog_id}]"
        end

        def wrapper_classes
          class_names("hidden": hidden?)
        end

        def card_classes
          class_names(
            "card bg-base-100 border-2 transition-all duration-200",
            "border-accent bg-accent/10": selected?,
            "border-base-300 opacity-50": !selected?
          )
        end

        def checkbox_visual_classes
          class_names(
            "w-6 h-6 rounded border-2 flex items-center justify-center transition-colors pointer-events-none",
            "bg-accent border-accent": selected?,
            "border-base-300": !selected?
          )
        end
      end
    end
  end
end
