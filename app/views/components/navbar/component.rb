# frozen_string_literal: true

module Navbar
  class Component < Application::Component
    def initialize(drawer_id: "main-drawer")
      @drawer_id = drawer_id
    end

    attr_reader :drawer_id

    def logout_path
      if helpers.rodauth(:admin).logged_in?
        helpers.rodauth(:admin).logout_path
      elsif helpers.rodauth(:employee).logged_in?
        helpers.rodauth(:employee).logout_path
      end
    end
  end
end
