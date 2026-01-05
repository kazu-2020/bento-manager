require "test_helper"

# Verifies multi-database configuration for development, production, and test environments.
#
# This test ensures that:
# - All environments (dev/prod/test) are configured with 4 databases: primary, cache, queue, cable
# - Database connections are valid and functional
# - Schema files exist for all databases
# - Configuration is consistent across environments
class DatabaseConfigurationTest < ActiveSupport::TestCase
  # Constants for multi-database configuration
  ENVIRONMENTS = %w[development production test].freeze
  SECONDARY_DATABASES = %w[cache queue cable].freeze
  ALL_DATABASES = ([ "primary" ] + SECONDARY_DATABASES).freeze

  # ========== Configuration Tests ==========

  test "primary database connection is configured" do
    assert_not_nil ActiveRecord::Base.connection,
      "Primary database connection should not be nil. Check database configuration."
  end

  test "all environments have multi-database configuration" do
    ENVIRONMENTS.each do |env|
      configs = ActiveRecord::Base.configurations.configs_for(env_name: env)
      database_names = configs.map(&:name)

      assert_equal ALL_DATABASES.sort, database_names.sort,
        "Environment '#{env}' should have databases: #{ALL_DATABASES.join(', ')}, " \
        "but found: #{database_names.join(', ')}"
    end
  end

  # ========== Connectivity Tests ==========

  test "primary database connection is valid" do
    assert_connection_valid(ActiveRecord::Base.connection, "primary database")
  end

  # ========== Schema File Tests ==========

  test "all schema files exist" do
    schema_files = {
      "primary" => "db/schema.rb",
      "cache" => "db/cache_schema.rb",
      "queue" => "db/queue_schema.rb",
      "cable" => "db/cable_schema.rb"
    }

    schema_files.each do |db_name, file_path|
      full_path = Rails.root.join(file_path)
      assert File.exist?(full_path),
        "Schema file for #{db_name} database should exist at #{file_path}"
    end
  end

  # ========== Environment Consistency Validation ==========

  test "all environments have identical database structure" do
    reference_structure = database_structure_for("development")

    %w[production test].each do |env|
      env_structure = database_structure_for(env)
      assert_equal reference_structure, env_structure,
        "Environment '#{env}' database structure should match development environment. " \
        "Inconsistencies: #{structure_diff(reference_structure, env_structure)}"
    end
  end

  private

  # Validates database connection by executing a simple query.
  # Provides detailed error message if connection fails.
  def assert_connection_valid(connection, db_description)
    assert_not_nil connection,
      "#{db_description.capitalize} connection should not be nil. " \
      "Check database configuration and ensure the database exists."

    # Execute a simple query to verify connection
    result = connection.execute("SELECT 1 AS test_value").first
    # SQLite returns a hash, ensure it has the expected value
    assert result["test_value"] == 1 || result[:test_value] == 1,
      "#{db_description.capitalize} should respond to queries. " \
      "Connection may be invalid or database may not be initialized."
  rescue => e
    flunk "#{db_description.capitalize} connection test failed: #{e.class.name} - #{e.message}. " \
          "Ensure database is created and schema is loaded."
  end

  # Returns a normalized structure of database configuration for an environment.
  # Used for comparing consistency across environments.
  def database_structure_for(env)
    configs = ActiveRecord::Base.configurations.configs_for(env_name: env)
    configs.map { |c|
      {
        name: c.name,
        adapter: c.adapter
      }
    }.sort_by { |c| c[:name] }
  end

  # Calculates differences between two database structures for detailed error messages.
  def structure_diff(structure1, structure2)
    diff = []

    structure1.each_with_index do |db1, idx|
      db2 = structure2[idx]
      next if db1 == db2

      diff << "Database '#{db1[:name]}': adapter mismatch"
    end

    diff.join("; ")
  end
end
