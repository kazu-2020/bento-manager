# frozen_string_literal: true

module Catalogs
  module List
    class Component < Application::Component
      def initialize(catalogs:)
        @catalogs = catalogs
      end

      attr_reader :catalogs

      def empty?
        catalogs.empty?
      end
    end
  end
end
