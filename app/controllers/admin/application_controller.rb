# frozen_string_literal: true

class Admin::ApplicationController < ::ApplicationController
  skip_before_action :require_authentication
  before_action -> { rodauth(:admin).require_account }
end
