# frozen_string_literal: true

class Employee::RodauthController < ApplicationController
  skip_before_action :require_authentication
  layout "auth"
end
