class RodauthController < ApplicationController
  skip_before_action :require_authentication

  # Used by Rodauth for rendering views, CSRF protection, running any
  # registered action callbacks and rescue handlers, instrumentation etc.

  # レコードが見つからない場合のハンドリング（認証状態を考慮）
  rescue_from ActiveRecord::RecordNotFound do |exception|
    Rails.logger.error("[Error] #{exception.class}: #{exception.message}")
    flash[:error] = I18n.t("custom_errors.controllers.record_not_found")

    if rodauth(:admin).logged_in? || rodauth(:employee).logged_in?
      redirect_back fallback_location: root_path
    else
      # リクエストパスに基づいて適切なログインページにリダイレクト
      login_path = request.path.start_with?("/admin") ? rodauth(:admin).login_path : rodauth(:employee).login_path
      redirect_to login_path
    end
  end

  # Controller callbacks and rescue handlers will run around Rodauth endpoints.
  # before_action :verify_captcha, only: :login, if: -> { request.post? }

  # Layout can be changed for all Rodauth pages or only certain pages.
  # layout "authentication"
  # layout -> do
  #   case rodauth.current_route
  #   when :login, :create_account, :verify_account, :verify_account_resend,
  #        :reset_password, :reset_password_request
  #     "authentication"
  #   else
  #     "application"
  #   end
  # end
end
