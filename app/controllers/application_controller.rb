class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # エラーハンドリング（優先度順: 具体的 → 汎用的）

  # CSRF検証失敗時のハンドリング（セキュリティイベント）
  rescue_from ActionController::InvalidAuthenticityToken do |exception|
    log_security_event(exception)
    flash[:error] = I18n.t("custom_errors.controllers.invalid_authenticity_token")

    redirect_to error_redirect_path
  end

  # レコードが見つからない場合のハンドリング
  rescue_from ActiveRecord::RecordNotFound do |exception|
    log_error(exception)
    flash[:error] = I18n.t("custom_errors.controllers.record_not_found")

    redirect_to error_redirect_path
  end

  # バリデーションエラー時のハンドリング
  rescue_from ActiveRecord::RecordInvalid do |exception|
    log_validation_error(exception)
    flash[:error] = I18n.t(
      "custom_errors.controllers.record_invalid",
      errors: exception.record.errors.full_messages.join(", ")
    )

    redirect_back fallback_location: error_redirect_path
  end

  # 汎用エラーハンドリング（最後の砦）
  rescue_from StandardError do |exception|
    log_unexpected_error(exception)
    flash[:error] = error_message_for_environment(exception)

    redirect_to error_redirect_path
  end

  private

  # Admin専用の認可制御
  # Employee認証時は403エラー、未認証時はAdminログインページにリダイレクト
  def require_admin_authentication
    # Employeeとしてログイン中 → 403エラー
    if rodauth(:employee).logged_in?
      render file: Rails.public_path.join("403.html"), status: :forbidden, layout: false
      return
    end

    # Admin認証チェック（未認証時はログインページにリダイレクト）
    unless rodauth(:admin).logged_in?
      redirect_to rodauth(:admin).login_path
    end
  end

  # エラーリダイレクト先（各コントローラーでオーバーライド可能）
  def error_redirect_path
    root_path
  end

  # セキュリティイベントのログ記録
  def log_security_event(exception)
    Rails.logger.warn(
      "[Security] CSRF token validation failed - " \
      "IP: #{request.remote_ip}, " \
      "User-Agent: #{request.user_agent}, " \
      "Path: #{request.path}"
    )
  end

  # エラーログ記録
  def log_error(exception)
    Rails.logger.error(
      "[Error] #{exception.class}: #{exception.message}"
    )
  end

  # バリデーションエラーのログ記録
  def log_validation_error(exception)
    Rails.logger.error(
      "[Error] Validation failed - " \
      "#{exception.class}: #{exception.message}, " \
      "Errors: #{exception.record.errors.full_messages.join(', ')}"
    )
  end

  # 予期しないエラーのログ記録
  def log_unexpected_error(exception)
    Rails.logger.error(
      "[Error] Unexpected error - " \
      "#{exception.class}: #{exception.message}\n" \
      "Backtrace: #{exception.backtrace.first(5).join("\n")}"
    )
  end

  # 環境に応じたエラーメッセージ
  def error_message_for_environment(exception)
    if Rails.env.development?
      I18n.t("custom_errors.controllers.standard_error.development", message: exception.message)
    else
      I18n.t("custom_errors.controllers.standard_error.production")
    end
  end
end
