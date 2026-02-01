ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Do not load fixtures automatically. Each test class should declare its own fixtures.
    # (Simply remove `fixtures :all` to achieve this behavior)

    # Add more helper methods to be used by all tests here...
  end
end

# Employee authentication test helpers (for integration tests)
class ActionDispatch::IntegrationTest
  # Login as an employee user
  # @param employee [Employee, Symbol] Employee object or fixture name (e.g., :verified_employee)
  # @param password [String] Password to use for login (default: "password")
  # @return [void]
  #
  # Example:
  #   login_as_employee(:verified_employee)
  #   login_as_employee(employees(:verified_employee))
  #   login_as_employee(employee, password: "custom_password")
  def login_as_employee(employee, password: "password")
    employee_username = employee.is_a?(Symbol) ? employees(employee).username : employee.username
    post "/employee/login", params: {
      username: employee_username,
      password: password
    }
    assert_response :redirect, "Failed to login as #{employee_username}"
    follow_redirect!
  end

  # Check if currently logged in as an employee
  # @return [Boolean] true if logged in, false otherwise
  #
  # Example:
  #   assert employee_logged_in?
  #   assert_not employee_logged_in?
  def employee_logged_in?
    session[:employee_account_id].present?
  end
end
