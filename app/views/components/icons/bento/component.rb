# frozen_string_literal: true

module Icons
  module Bento
    class Component < Icons::Base::Component
      def icon_path
        # Bento box icon (food container with compartments)
        '<path stroke-linecap="round" stroke-linejoin="round" d="M3 6h18M3 6v12a2 2 0 002 2h14a2 2 0 002-2V6M3 6a2 2 0 012-2h14a2 2 0 012 2M9 6v14M15 6v14M3 12h18" />'
      end
    end
  end
end
