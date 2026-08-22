# frozen_string_literal: true

module Pos
  module DailyInventories
    module NewFormItemCard
      class Component < Application::Component
        def initialize(item:, form:)
          @item = item
          @form = form
        end

        attr_reader :item, :form

        delegate :catalog_id, :catalog_name, :selected?, :stock, to: :item

        # 絞り込みの判断はカードが form に聞く。真偽値を呼び出し側に計算させると、
        # フルページ描画と turbo_stream のどちらかが渡し忘れても例外にならず、
        # その経路だけ絞り込みが効かないまま黙って出る
        def hidden?
          !form.visible?(item)
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
            "border-primary bg-primary/10": selected?,
            "border-base-300 opacity-50": !selected?
          )
        end

        def checkbox_visual_classes
          class_names(
            "w-6 h-6 rounded border-2 flex items-center justify-center transition-colors pointer-events-none",
            "bg-primary border-primary": selected?,
            "border-base-300": !selected?
          )
        end
      end
    end
  end
end
