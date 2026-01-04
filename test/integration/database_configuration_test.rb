require "test_helper"

class DatabaseConfigurationTest < ActiveSupport::TestCase
  test "primary database connection is configured" do
    assert_not_nil ActiveRecord::Base.connection
  end

  test "development cache database is configured" do
    cache_config = ActiveRecord::Base.configurations.configs_for(env_name: "development", name: "cache")
    assert_not_nil cache_config
    assert_equal "db/cache_migrate", cache_config.migrations_paths
  end

  test "development queue database is configured" do
    queue_config = ActiveRecord::Base.configurations.configs_for(env_name: "development", name: "queue")
    assert_not_nil queue_config
    assert_equal "db/queue_migrate", queue_config.migrations_paths
  end

  test "development cable database is configured" do
    cable_config = ActiveRecord::Base.configurations.configs_for(env_name: "development", name: "cable")
    assert_not_nil cable_config
    assert_equal "db/cable_migrate", cable_config.migrations_paths
  end

  test "production cache database is configured" do
    cache_config = ActiveRecord::Base.configurations.configs_for(env_name: "production", name: "cache")
    assert_not_nil cache_config
    assert_equal "db/cache_migrate", cache_config.migrations_paths
  end

  test "production queue database is configured" do
    queue_config = ActiveRecord::Base.configurations.configs_for(env_name: "production", name: "queue")
    assert_not_nil queue_config
    assert_equal "db/queue_migrate", queue_config.migrations_paths
  end

  test "production cable database is configured" do
    cable_config = ActiveRecord::Base.configurations.configs_for(env_name: "production", name: "cable")
    assert_not_nil cable_config
    assert_equal "db/cable_migrate", cable_config.migrations_paths
  end

  test "primary schema file exists" do
    assert File.exist?(Rails.root.join("db", "schema.rb"))
  end

  test "cache schema file exists" do
    assert File.exist?(Rails.root.join("db", "cache_schema.rb"))
  end

  test "queue schema file exists" do
    assert File.exist?(Rails.root.join("db", "queue_schema.rb"))
  end

  test "cable schema file exists" do
    assert File.exist?(Rails.root.join("db", "cable_schema.rb"))
  end
end
