class RodauthController < ApplicationController
  # Used by Rodauth for rendering views, CSRF protection, running any
  # registered action callbacks and rescue handlers, instrumentation etc.

  # エラーハンドリング
  # CSRF検証失敗時のハンドリング（セキュリティイベント）
  rescue_from ActionController::InvalidAuthenticityToken do |exception|
    Rails.logger.warn "[Security] CSRF token validation failed - IP: #{request.remote_ip}, User-Agent: #{request.user_agent}, Path: #{request.path}"
    flash[:error] = "セキュリティトークンが無効です。ページを再読み込みしてもう一度お試しください。"
    redirect_to rodauth(:admin).login_path
  end

  # レコードが見つからない場合のハンドリング
  rescue_from ActiveRecord::RecordNotFound do |exception|
    Rails.logger.error "[Error] Record not found - #{exception.class}: #{exception.message}"
    flash[:error] = "指定されたデータが見つかりませんでした。"
    redirect_to rodauth(:admin).login_path
  end

  # バリデーションエラー時のハンドリング
  rescue_from ActiveRecord::RecordInvalid do |exception|
    Rails.logger.error "[Error] Validation failed - #{exception.class}: #{exception.message}, Errors: #{exception.record.errors.full_messages.join(', ')}"
    flash[:error] = "入力内容に誤りがあります: #{exception.record.errors.full_messages.join(', ')}"
    redirect_back fallback_location: rodauth(:admin).login_path
  end

  # 汎用エラーハンドリング（最後の砦）
  rescue_from StandardError do |exception|
    Rails.logger.error "[Error] Unexpected error in RodauthController - #{exception.class}: #{exception.message}\nBacktrace: #{exception.backtrace.first(5).join("\n")}"

    if Rails.env.development?
      flash[:error] = "エラーが発生しました: #{exception.message}"
    else
      flash[:error] = "予期しないエラーが発生しました。しばらく時間をおいてから再度お試しください。"
    end

    redirect_to rodauth(:admin).login_path
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
