# frozen_string_literal: true

module Discounts
  module Show
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"
      HEADER_FRAME_ID = "discount_header_frame"

      def initialize(discount:)
        @discount = discount
      end

      attr_reader :discount

      delegate :name, :valid_from, :valid_until, :status, :expired?, :upcoming?, to: :discount

      def header_frame_id
        HEADER_FRAME_ID
      end

      def back_path
        helpers.discounts_path
      end
    end
  end
end
