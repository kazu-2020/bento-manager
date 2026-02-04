class RodauthApp < Rodauth::Rails::App
  # Employee configuration
  configure RodauthEmployee, :employee

  route do |r|
    # 処理順序が重要:
    # 1. load_memory: Remember cookie からセッション復元
    #    - r.rodauth の前に呼ぶ必要がある
    #    - セッション期限切れでログインページにリダイレクトされた際、
    #      Remember cookie があればセッションを復元し、already_logged_in でホームへリダイレクト
    # 2. r.rodauth: ログイン/ログアウト等の認証ルートを処理
    # 3. check_session_expiration: セッション有効期限をチェック
    rodauth(:employee).load_memory
    r.rodauth(:employee)
    rodauth(:employee).check_session_expiration

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
