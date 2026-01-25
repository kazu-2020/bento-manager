# frozen_string_literal: true

module Discounts
  module StatusBadge
    class Component < Application::Component
      def initialize(status:)
        @status = status
      end

      attr_reader :status

      def badge_class
        case status
        when :active then "badge-success"
        when :expired then "badge-error"
        when :upcoming then "badge-warning"
        end
      end
    end
  end
end
