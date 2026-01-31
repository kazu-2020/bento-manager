require "sequel/core"

class RodauthEmployee < Rodauth::Rails::Auth
  configure do
    # Employee authentication features
    # Employees are created and managed by Admin via web UI.
    # Email-based features (:verify_account, :reset_password, :change_login) are excluded
    # as employees are created directly with verified status by Admin.
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
    rails_controller { RodauthController }

    # Make built-in page titles accessible in your views via an instance variable.
    title_instance_variable :@page_title

    # Store account status in an integer column without foreign key constraint.
    account_status_column :status

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
    # already_logged_in { redirect login_redirect }

    # ==> Flash
    # Match flash keys with ones already used in the Rails app.
    # flash_notice_key :success # default is :notice
    # flash_error_key :error # default is :alert

    # Override default flash messages.
    # create_account_notice_flash "Your account has been created. Please verify your account by visiting the confirmation link sent to your email address."
    # require_login_error_flash "Login is required for accessing this page"
    # login_notice_flash nil

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
