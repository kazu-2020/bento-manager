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

          def catalog_id
            item[:catalog_id]
          end

          def catalog_name
            item[:catalog_name]
          end

          def dom_id
            "bento-card-#{catalog_id}"
          end

          def selected?
            item[:selected]
          end

          def stock
            item[:stock]
          end

          def field_name_prefix
            "inventory[#{catalog_id}]"
          end

          def card_classes
            base = "card bg-base-100 border-2 transition-all duration-200"
            if selected?
              "#{base} border-accent bg-accent/10"
            else
              "#{base} border-base-300 opacity-50"
            end
          end

          def checkbox_visual_classes
            base = "w-6 h-6 rounded border-2 flex items-center justify-center transition-colors pointer-events-none"
            if selected?
              "#{base} bg-accent border-accent"
            else
              "#{base} border-base-300"
            end
          end
        end
      end
    end
  end
end
