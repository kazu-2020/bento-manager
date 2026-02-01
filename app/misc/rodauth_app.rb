class RodauthApp < Rodauth::Rails::App
  # Admin configuration
  configure RodauthAdmin, :admin

  # Employee configuration
  configure RodauthEmployee, :employee

  route do |r|
    r.rodauth(:admin) # route admin rodauth requests
    r.rodauth(:employee) # route employee rodauth requests

    # Admin: セッション有効期限チェック
    rodauth(:admin).check_session_expiration if rodauth(:admin).logged_in?

    # Employee: Remember cookie からセッション復元 + 有効期限チェック
    # 管理者がログイン中の場合は load_memory をスキップ
    # （load_memory が clear_session を呼び、admin セッションを上書きするのを防ぐ）
    rodauth(:employee).load_memory unless rodauth(:admin).logged_in?
    rodauth(:employee).check_session_expiration if rodauth(:employee).logged_in?

    # ==> Authenticating requests
    # Call `rodauth.require_account` for requests that you want to
    # require authentication for. For example:
    #
    # # authenticate /dashboard/* and /account/* requests
    # if r.path.start_with?("/dashboard") || r.path.start_with?("/account")
    #   rodauth.require_account
    # end
  end
end
