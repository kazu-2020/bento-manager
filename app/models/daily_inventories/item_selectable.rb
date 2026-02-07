# frozen_string_literal: true

module DailyInventories
  module ItemSelectable
    def visible?(item)
      return true if search_query.blank?

      item.catalog_name.include?(search_query)
    end

    def selected_items
      items.select(&:selected?)
    end

    def selected_count
      selected_items.count
    end

    def bento_items
      items.select { |item| item.category == "bento" }
    end

    def side_menu_items
      items.select { |item| item.category == "side_menu" }
    end
  end
end
