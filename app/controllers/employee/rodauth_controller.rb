# frozen_string_literal: true

class Employee::RodauthController < ApplicationController
  skip_before_action :require_authentication
  layout "auth"

  rescue_from ActiveRecord::RecordNotFound do |exception|
    log_error(exception)
    flash[:error] = I18n.t("custom_errors.controllers.record_not_found")

    if rodauth(:employee).logged_in?
      redirect_back fallback_location: root_path
    else
      redirect_to rodauth(:employee).login_path
    end
  end
end
