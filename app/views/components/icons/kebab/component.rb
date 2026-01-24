# frozen_string_literal: true

module Icons
  module Kebab
    class Component < Icons::Base::Component
      def icon_path
        '<circle cx="12" cy="5" r="1" fill="currentColor" />' \
        '<circle cx="12" cy="12" r="1" fill="currentColor" />' \
        '<circle cx="12" cy="19" r="1" fill="currentColor" />'
      end
    end
  end
end
