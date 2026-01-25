# frozen_string_literal: true

module Discounts
  module BasicInfoForm
    class Component < Application::Component
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(discount:)
        @discount = discount
      end

      attr_reader :discount

      def frame_id
        Discounts::BasicInfo::Component::FRAME_ID
      end

      def discount_path
        helpers.discount_path(discount, section: :basic_info)
      end

      def cancel_path
        helpers.discount_path(discount)
      end

      def card_classes
        CARD_CLASSES
      end
    end
  end
end
