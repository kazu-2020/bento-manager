# frozen_string_literal: true

module Pos
  module DailyInventories
    module NewForm
      module BentoCard
        class Component < Application::Component
          def initialize(item:)
            @item = item
          end

          attr_reader :item

          delegate :catalog_id, :catalog_name, :selected?, :stock, to: :item

          def dom_id
            "bento-card-#{catalog_id}"
          end

          def field_name_prefix
            "inventory[#{catalog_id}]"
          end

          def card_classes
            base_classes = %w[card bg-base-100 border-2 transition-all duration-200]
            state_classes = selected? ? %w[border-accent bg-accent/10] : %w[border-base-300 opacity-50]
            (base_classes + state_classes).join(" ")
          end

          def checkbox_visual_classes
            base_classes = %w[w-6 h-6 rounded border-2 flex items-center justify-center transition-colors pointer-events-none]
            state_classes = selected? ? %w[bg-accent border-accent] : %w[border-base-300]
            (base_classes + state_classes).join(" ")
          end
        end
      end
    end
  end
end
