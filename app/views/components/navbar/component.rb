# frozen_string_literal: true

module Navbar
  class Component < Application::Component
    def initialize(drawer_id: "main-drawer")
      @drawer_id = drawer_id
    end

    attr_reader :drawer_id

    def logout_path
      helpers.rodauth(:employee).logout_path if helpers.rodauth(:employee).logged_in?
    rescue KeyError
      nil
    end
  end
end
