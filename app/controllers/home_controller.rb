# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :require_authentication

  def index; end
end
