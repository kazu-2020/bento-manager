# frozen_string_literal: true

module Navbar
  class Component < Application::Component
    def initialize(drawer_id: "main-drawer", title: nil)
      @drawer_id = drawer_id
      @title = title
    end

    attr_reader :drawer_id

    def display_title
      @title.presence || "弁当販売管理"
    end

    def logout_path
      helpers.rodauth(:employee).logout_path if helpers.rodauth(:employee).logged_in?
    rescue KeyError
      nil
    end
  end
end
