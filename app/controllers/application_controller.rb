# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_authentication

  private

  def require_authentication
    rodauth(:employee).require_account
  end

  def current_employee
    rodauth(:employee).rails_account
  end
end
