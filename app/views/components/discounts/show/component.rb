# frozen_string_literal: true

module Discounts
  module Show
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(discount:)
        @discount = discount
      end

      attr_reader :discount

      delegate :name, :valid_from, :valid_until, to: :discount

      def back_path
        helpers.discounts_path
      end

      def status
        return :expired if expired?
        return :upcoming if upcoming?

        :active
      end

      def expired?
        valid_until.present? && valid_until < Date.current
      end

      def upcoming?
        valid_from > Date.current
      end
    end
  end
end
