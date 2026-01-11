# frozen_string_literal: true

class NavbarComponent < ApplicationComponent
  def initialize(drawer_id: "main-drawer")
    @drawer_id = drawer_id
  end

  private

  attr_reader :drawer_id
end
