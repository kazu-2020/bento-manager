# frozen_string_literal: true

module Navbar
  class Component < Application::Component
    def initialize(drawer_id: "main-drawer")
      @drawer_id = drawer_id
    end

    attr_reader :drawer_id
  end
end
