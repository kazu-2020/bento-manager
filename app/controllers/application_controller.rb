# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_authentication

  rescue_from ActionController::InvalidAuthenticityToken do |exception|
    log_security_event(exception)
    flash[:error] = I18n.t("custom_errors.controllers.invalid_authenticity_token")
    redirect_to error_redirect_path
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    log_error(exception)
    flash[:error] = I18n.t("custom_errors.controllers.record_not_found")
    redirect_to error_redirect_path
  end

  rescue_from ActiveRecord::RecordInvalid do |exception|
    log_validation_error(exception)
    flash[:error] = I18n.t(
      "custom_errors.controllers.record_invalid",
      errors: exception.record.errors.full_messages.join(", ")
    )
    redirect_back fallback_location: error_redirect_path
  end

  rescue_from StandardError do |exception|
    raise exception if Rails.env.test?
    log_unexpected_error(exception)
    flash[:error] = error_message_for_environment(exception)
    redirect_to error_redirect_path
  end

  private

  def require_authentication
    return if rodauth(:employee).logged_in?

    flash[:error] = I18n.t("custom_errors.controllers.require_authentication")
    redirect_to rodauth(:employee).login_path
  end

  def error_redirect_path
    root_path
  end

  def log_security_event(_exception)
    Rails.logger.warn(
      "[Security] CSRF token validation failed - " \
      "IP: #{request.remote_ip}, " \
      "User-Agent: #{request.user_agent}, " \
      "Path: #{request.path}"
    )
  end

  def log_error(exception)
    Rails.logger.error("[Error] #{exception.class}: #{exception.message}")
  end

  def log_validation_error(exception)
    Rails.logger.error(
      "[Error] Validation failed - " \
      "#{exception.class}: #{exception.message}, " \
      "Errors: #{exception.record.errors.full_messages.join(', ')}"
    )
  end

  def log_unexpected_error(exception)
    Rails.logger.error(
      "[Error] Unexpected error - " \
      "#{exception.class}: #{exception.message}\n" \
      "Backtrace: #{exception.backtrace.first(5).join("\n")}"
    )
  end

  def error_message_for_environment(exception)
    if Rails.env.development?
      I18n.t("custom_errors.controllers.standard_error.development", message: exception.message)
    else
      I18n.t("custom_errors.controllers.standard_error.production")
    end
  end
end
