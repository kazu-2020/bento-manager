# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_authentication

  private

  def require_authentication
    return if rodauth(:employee).logged_in?

    flash[:error] = I18n.t("custom_errors.controllers.require_authentication")
    redirect_to rodauth(:employee).login_path
  end
end
