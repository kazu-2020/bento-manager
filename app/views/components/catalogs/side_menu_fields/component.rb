# frozen_string_literal: true

module Catalogs
  module SideMenuFields
    class Component < Application::Component
      def initialize(errors: nil)
        @errors = errors || ActiveModel::Errors.new(nil)
      end

      attr_reader :errors

      def name_error?
        errors[:name].any?
      end

      def regular_price_error?
        errors[:regular_price].any?
      end

      def bundle_price_error?
        errors[:bundle_price].any?
      end
    end
  end
end
