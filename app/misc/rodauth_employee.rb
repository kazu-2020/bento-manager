require "sequel/core"

class RodauthEmployee < Rodauth::Rails::Auth
  configure do
    # Employee authentication features
    # 従業員アカウントは店主が rails console / db:seed で作る。作成用の画面はまだ無い。
    # メールを使う機能（:verify_account, :reset_password, :change_login）は入れていない。
    # 連絡先メールアドレスを持たないため、確認も再発行もメールでは行えない。
    # :lockout is enabled for brute-force protection.
    enable :login, :logout, :change_password, :close_account, :lockout, :session_expiration, :remember

    # See the Rodauth documentation for the list of available config options:
    # http://rodauth.jeremyevans.net/documentation.html

    # ==> General
    # Initialize Sequel and have it reuse Active Record's database connection.
    db Sequel.sqlite(extensions: :activerecord_connection, keep_reference: false)
    # Avoid DB query that checks accounts table schema at boot time.
    convert_token_id_to_integer? { Employee.columns_hash["id"].type == :integer }

    # Change prefix of table and foreign key column names from default "account"
    accounts_table :employees

    # The secret key used for hashing public-facing tokens for various features.
    # Defaults to Rails `secret_key_base`, but you can use your own secret key.
    # hmac_secret "..."

    # Use path prefix for all Employee routes.
    prefix "/employee"

    # Use unique session key for Employee to distinguish from Admin
    session_key :employee_account_id

    # Specify the controller used for view rendering, CSRF, and callbacks.
    rails_controller { Employee::RodauthController }

    # Make built-in page titles accessible in your views via an instance variable.
    title_instance_variable :@page_title

    # Store account status in an integer column without foreign key constraint.
    account_status_column :status

    # アカウント状態は「有効」と「閉鎖」の 2 つで閉じている（ADR-0007）。
    # Rodauth の既定値（2 / 3）と Employee の enum は今たまたま一致しているだけなので、
    # enum から引いて導出する。状態を足したときに片方だけずれるのを防ぐ。
    account_open_status_value { Employee.statuses.fetch("verified") }
    account_closed_status_value { Employee.statuses.fetch("closed") }

    # unverified は Rodauth がメール確認フロー用に用意した状態で、この製品には
    # 対応する出来事が無い。既定値 1 のままだと DB に 1 が混入したとき、Rodauth はそれを
    # 「見つかったが未確認のアカウント」として 403 と
    # 「verify account before logging in」で弾く。存在しない手続きを案内することになる。
    #
    # enum にも DB にも存在しない 0 を番兵として置く。_account_from_login の述語が
    # status IN (0, 2) になり、1 の行は候補から外れて、存在しないログイン名と同じ 401 になる。
    #
    # 有効と同じ値に倒してはいけない。verify_account は account_initial_status_value を
    # この値へ上書きし（verify_account.rb:202-204）、create_account がそれを新規行に書く
    # （create_account.rb:124）。有効と同じ値だと、確認リンクを踏まないアカウントが
    # 最初からログインでき業務画面まで到達する。例外もテスト失敗も出ない。
    account_unverified_status_value 0

    # Store password hash in a column instead of a separate table.
    account_password_hash_column :password_hash

    # Change some default param keys.
    login_param "username"
    login_column :username
    require_email_address_logins? false
    # password_confirm_param "confirm_password"

    # Redirect back to originally requested location after authentication.
    # login_return_to_requested_location? true
    # two_factor_auth_return_to_requested_location? true # if using MFA

    # Autologin the user after they have reset their password.
    # reset_password_autologin? true

    # Delete the account record when the user has closed their account.
    # delete_account_on_close? true

    # Redirect to the app from login and registration pages if already logged in.
    already_logged_in { redirect login_redirect }

    # ==> Flash
    # Match flash keys with ones already used in the Rails app.
    # flash_notice_key :success # default is :notice
    # flash_error_key :error # default is :alert

    # Override default flash messages.
    login_notice_flash { I18n.t("rodauth.login.success") }
    login_error_flash { I18n.t("rodauth.login.error") }
    require_login_error_flash { I18n.t("custom_errors.controllers.require_authentication") }
    change_password_notice_flash { I18n.t("rodauth.change_password.success") }
    logout_notice_flash { I18n.t("rodauth.logout.success") }
    session_expiration_error_flash { I18n.t("rodauth.session_expired") }

    # ==> Validation
    # Override default validation error messages.
    # no_matching_login_message "user with this email address doesn't exist"
    # already_an_account_with_this_login_message "user with this email address already exists"
    # password_too_short_message { "needs to have at least #{password_minimum_length} characters" }
    # login_does_not_meet_requirements_message { "invalid email#{", #{login_requirement_message}" if login_requirement_message}" }

    # Passwords shorter than 8 characters are considered weak according to OWASP.
    password_minimum_length 8
    # bcrypt has a maximum input length of 72 bytes, truncating any extra bytes.
    password_maximum_bytes 72

    # Custom password complexity requirements (alternative to password_complexity feature).
    # password_meets_requirements? do |password|
    #   super(password) && password_complex_enough?(password)
    # end
    # auth_class_eval do
    #   def password_complex_enough?(password)
    #     return true if password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)
    #     set_password_requirement_error_message(:password_simple, "requires one number and one special character")
    #     false
    #   end
    # end

    # ==> Hooks
    # Validate custom fields in the create account form.
    # before_create_account do
    #   throw_error_status(422, "name", "must be present") if param("name").empty?
    # end

    # Perform additional actions after the account is created.
    # after_create_account do
    #   Profile.create!(account_id: account_id, name: param("name"))
    # end

    # Do additional cleanup after the account is closed.
    # after_close_account do
    #   Profile.find_by!(account_id: account_id).destroy
    # end

    # ==> Lockout
    # Brute-force protection configuration
    # Maximum number of failed logins before account is locked (default: 100)
    max_invalid_logins 5
    # Use custom table names for employee accounts
    account_login_failures_table :employee_login_failures
    account_lockouts_table :employee_lockouts

    # ==> Session Expiration
    # セッション有効期限: 24時間
    max_session_lifetime 86_400

    # ==> Remember Login
    # Remember Login: 30日間
    remember_period days: 30
    remember_cookie_key "_bento_manager_employee_remember"
    extend_remember_deadline? true
    remember_cookie_options httponly: true, same_site: :lax

    # Remember テーブル名を employee 用に変更
    remember_table :employee_remember_keys

    # ログイン成功後に常に remember cookie を設定
    after_login do
      remember_login
    end

    # ログアウト時に remember cookie を削除
    after_logout do
      forget_login
    end

    # ==> Redirects
    # Redirect to home page after logout.
    logout_redirect "/"
  end
end
