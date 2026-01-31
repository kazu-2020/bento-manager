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
    rodauth(:employee).load_memory  # remember cookie があれば自動ログイン
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
