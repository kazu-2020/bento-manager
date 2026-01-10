# frozen_string_literal: true

class RodauthController < ApplicationController
  skip_before_action :require_authentication

  rescue_from ActiveRecord::RecordNotFound do |exception|
    log_error(exception)
    flash[:error] = I18n.t("custom_errors.controllers.record_not_found")

    if rodauth(:admin).logged_in? || rodauth(:employee).logged_in?
      redirect_back fallback_location: root_path
    else
      redirect_to appropriate_login_path
    end
  end

  private

  def appropriate_login_path
    if request.path.start_with?("/admin")
      rodauth(:admin).login_path
    else
      rodauth(:employee).login_path
    end
  end
end
