class RodauthApp < Rodauth::Rails::App
  # Admin configuration
  configure RodauthAdmin, :admin

  # Employee configuration
  configure RodauthEmployee, :employee

  route do |r|
    r.rodauth(:admin) # route admin rodauth requests
    r.rodauth(:employee) # route employee rodauth requests

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
