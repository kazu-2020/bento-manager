# frozen_string_literal: true

module Discounts
  module List
    class Component < Application::Component
      def initialize(discounts:)
        @discounts = discounts
      end

      attr_reader :discounts

      def empty?
        discounts.empty?
      end
    end
  end
end
