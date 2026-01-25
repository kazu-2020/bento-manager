# frozen_string_literal: true

module Discounts
  module BasicInfo
    class Component < Application::Component
      FRAME_ID = "discount_basic_info_frame"
      CARD_CLASSES = "card bg-base-100 shadow-sm border-2 border-base-300"

      def initialize(discount:)
        @discount = discount
      end

      attr_reader :discount

      delegate :name, :valid_from, :valid_until, to: :discount

      def frame_id
        FRAME_ID
      end

      def edit_path
        helpers.edit_discount_path(discount, section: :basic_info)
      end

      def card_classes
        helpers.class_names(CARD_CLASSES, "opacity-75" => expired?)
      end

      def formatted_valid_from
        helpers.l(valid_from, format: :long) if valid_from
      end

      def formatted_valid_until
        valid_until ? helpers.l(valid_until, format: :long) : t(".no_end_date")
      end

      def created_at_formatted
        helpers.l(discount.created_at, format: :long) if discount.created_at
      end

      def updated_at_formatted
        helpers.l(discount.updated_at, format: :long) if discount.updated_at
      end

      private

      def expired?
        valid_until.present? && valid_until < Date.current
      end
    end
  end
end
