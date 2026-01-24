# frozen_string_literal: true

module Catalogs
  module BentoFields
    class Component < Application::Component
      def initialize(creator: nil)
        @creator = creator
      end

      attr_reader :creator

      def name_error?
        creator&.catalog&.errors&.where(:name)&.any? || false
      end

      def regular_price_error?
        creator&.regular_price_record&.errors&.where(:price)&.any? || false
      end
    end
  end
end
