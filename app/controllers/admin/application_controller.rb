# frozen_string_literal: true

class Admin::ApplicationController < ::ApplicationController
  before_action -> { rodauth(:admin).require_account }
end
