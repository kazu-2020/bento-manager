class RodauthApp < Rodauth::Rails::App
  # Employee configuration
  configure RodauthEmployee, :employee

  route do |r|
    r.rodauth(:employee) # route employee rodauth requests

    # Employee: Remember cookie からセッション復元 + 有効期限チェック
    rodauth(:employee).load_memory
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
