# frozen_string_literal: true

module Locations
  module Switcher
    class Component < Application::Component
      # path_builder: 販売先 ID を受け取り、現在の画面状態を保ったまま
      # 販売先だけ差し替えた URL を返す callable
      def initialize(locations:, selected:, path_builder:)
        @locations = locations
        @selected = selected
        @path_builder = path_builder
      end

      private

      attr_reader :locations, :selected, :path_builder

      def selected?(loc)
        loc.id == selected.id
      end
    end
  end
end
