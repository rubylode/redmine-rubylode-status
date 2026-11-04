require_relative "support/cross_plugin_test_helper"

# Area 7: saved 1.x settings are moved to the 2.0.0 names by `rake redmine:plugins:migrate`, and moved back by the reverse
# migration (VERSION=0 for that plugin). The real rake tasks run in a child process against the same test database.
class CrossPluginUpgradePathTest < ActiveSupport::TestCase
  include CrossPluginTestHelpers

  # The tasks change the database from another process, so no test here may sit inside a transaction.
  self.use_transactional_tests = false

  PLUGIN_NAMES = WIDGET_KEYS.map { |key| "redmine_rubylode_#{key}" }.freeze

  VERSION_ONE_SETTINGS = {
    "beszel" => { "hub_url" => "http://beszel.example.test:8090/", "show_on_paths" => "/projects/*\n/issues\n/wiki/*/edit",
                  "block_title" => "My servers", "systems" => "web | web-1 | Web server", "visibility" => "admins" },
    "glitchtip" => { "base_url" => "https://glitchtip.example.test", "organization_slug" => "acme", "lookback_hours" => "48",
                     "path_patterns" => "/projects/*/issues\n/wiki*", "block_title" => "Errors needing attention",
                     "show_on_my_page" => "1" },
    "uptime_kuma" => { "metrics_url" => "https://uptime.example.test/metrics", "services" => "Site | https://example.test | x | Site" },
    "windmill" => { "windmill_url" => "https://windmill.example.test", "workspace_id" => "main", "block_title" => "Jobs" }
  }.freeze

  setup do
    clear_saved_settings
  end

  teardown do
    clear_saved_settings
  end

  def clear_saved_settings
    PLUGIN_NAMES.each { |name| Setting.where(name: "plugin_#{name}").delete_all }
    Setting.clear_cache
  end

  def rake_plugins_migrate(arguments = {})
    environment = { "RAILS_ENV" => "test" }
    succeeded = system(environment, "bundle", "exec", "rake", "redmine:plugins:migrate", *arguments.map { |name, value| "#{name}=#{value}" },
                       chdir: Rails.root.to_s, out: File::NULL, err: File::NULL)
    assert succeeded, "rake redmine:plugins:migrate #{arguments} failed"
    Setting.clear_cache
  end

  def saved(key)
    Setting.clear_cache
    Setting.send(:"plugin_redmine_rubylode_#{key}").to_h.stringify_keys
  end

  def seed_version_one_settings
    # The test database already ran the 2.0.0 migrations at start-up, with nothing saved. Take each plugin back to
    # version 0 first, so the next migrate run really has them to apply.
    PLUGIN_NAMES.each { |name| rake_plugins_migrate("NAME" => name, "VERSION" => "0") }
    VERSION_ONE_SETTINGS.each { |key, values| Setting.send(:"plugin_redmine_rubylode_#{key}=", values) }
    Setting.clear_cache
  end

  test "one plain migrate run moves every plugin's saved 1.x settings to the new keys and values" do
    seed_version_one_settings
    rake_plugins_migrate

    beszel = saved("beszel")
    assert_equal "http://beszel.example.test:8090", beszel["base_url"].to_s.chomp("/"), "hub_url should become base_url"
    assert_not beszel.key?("hub_url")
    assert_not beszel.key?("show_on_paths")
    assert_equal "/projects/**\n/issues\n/wiki/**/edit", beszel["matching_page_paths"]
    assert_equal "1", beszel["show_on_matching_pages"]
    assert_equal "My servers", beszel["block_title"]
    assert_equal "admins", beszel["visibility"]

    glitchtip = saved("glitchtip")
    assert_equal "48", glitchtip["look_back_hours"]
    assert_not glitchtip.key?("lookback_hours")
    assert_not glitchtip.key?("path_patterns")
    assert_equal "/projects/**/issues\n/wiki**", glitchtip["matching_page_paths"]
    assert_equal "1", glitchtip["show_on_matching_pages"]
    assert_equal "Errors", glitchtip["block_title"]
    assert_equal "0", glitchtip["show_on_my_page"]
    assert_equal "acme", glitchtip["organization_slug"]

    uptime_kuma = saved("uptime_kuma")
    assert_equal "https://uptime.example.test", uptime_kuma["base_url"], "the /metrics suffix should be stripped"
    assert_not uptime_kuma.key?("metrics_url")
    assert_equal "Site | https://example.test | x | Site", uptime_kuma["services"]

    windmill = saved("windmill")
    assert_equal "https://windmill.example.test", windmill["base_url"]
    assert_not windmill.key?("windmill_url")
    assert_equal "Jobs", windmill["block_title"]
  end

  test "the migrated settings are what the plugins' Settings classes read" do
    seed_version_one_settings
    rake_plugins_migrate

    assert_equal "http://beszel.example.test:8090", RubylodeBeszel::Settings.current.base_url
    assert_equal ["/projects/**", "/issues", "/wiki/**/edit"], RubylodeBeszel::Settings.current.matching_page_patterns.map(&:to_s)
    assert_equal "Errors", RubylodeGlitchtip::Settings.current.block_title
    assert_equal 48, RubylodeGlitchtip::Settings.current.look_back_hours
    assert_not RubylodeGlitchtip::Settings.current.show_on_my_page?
    assert_equal "https://uptime.example.test/metrics", RubylodeUptimeKuma::Settings.current.metrics_url
    assert_equal "https://windmill.example.test", RubylodeWindmill::Settings.current.base_url
  end

  test "running migrate a second time changes nothing" do
    seed_version_one_settings
    rake_plugins_migrate
    after_first_run = WIDGET_KEYS.to_h { |key| [key, saved(key)] }
    rake_plugins_migrate

    assert_equal after_first_run, WIDGET_KEYS.to_h { |key| [key, saved(key)] }
  end

  test "the reverse migration of each plugin brings the 1.x shape back" do
    seed_version_one_settings
    rake_plugins_migrate
    PLUGIN_NAMES.each { |name| rake_plugins_migrate("NAME" => name, "VERSION" => "0") }

    beszel = saved("beszel")
    assert_equal "http://beszel.example.test:8090", beszel["hub_url"].to_s.chomp("/")
    assert_equal "/projects/*\n/issues\n/wiki/*/edit", beszel["show_on_paths"]
    %w[base_url matching_page_paths show_on_matching_pages].each { |name| assert_not beszel.key?(name), "beszel still has #{name}" }

    glitchtip = saved("glitchtip")
    assert_equal "48", glitchtip["lookback_hours"]
    assert_equal "/projects/*/issues\n/wiki*", glitchtip["path_patterns"]
    assert_equal "Errors needing attention", glitchtip["block_title"]
    assert_equal "1", glitchtip["show_on_my_page"]
    %w[look_back_hours matching_page_paths show_on_matching_pages].each { |name| assert_not glitchtip.key?(name), "glitchtip still has #{name}" }

    uptime_kuma = saved("uptime_kuma")
    assert_equal "https://uptime.example.test/metrics", uptime_kuma["metrics_url"]
    assert_not uptime_kuma.key?("base_url")

    windmill = saved("windmill")
    assert_equal "https://windmill.example.test", windmill["windmill_url"]
    assert_not windmill.key?("base_url")
  end

  test "reversing one plugin leaves the others' new keys alone" do
    seed_version_one_settings
    rake_plugins_migrate
    rake_plugins_migrate("NAME" => "redmine_rubylode_windmill", "VERSION" => "0")

    assert saved("windmill").key?("windmill_url")
    assert saved("beszel").key?("base_url")
    assert saved("glitchtip").key?("look_back_hours")
    assert saved("uptime_kuma").key?("base_url")
  end

  test "a fresh install with nothing saved writes no settings" do
    PLUGIN_NAMES.each { |name| rake_plugins_migrate("NAME" => name, "VERSION" => "0") }
    rake_plugins_migrate

    PLUGIN_NAMES.each { |name| assert_not Setting.where(name: "plugin_#{name}").exists?, "#{name} saved settings from nothing" }
  end

  test "a Kuma address with a path and a trailing slash after /metrics loses the slash and the suffix" do
    PLUGIN_NAMES.each { |name| rake_plugins_migrate("NAME" => name, "VERSION" => "0") }
    Setting.send(:plugin_redmine_rubylode_uptime_kuma=, { "metrics_url" => "https://uptime.example.test/status/metrics/" })
    rake_plugins_migrate("NAME" => "redmine_rubylode_uptime_kuma")

    assert_equal "https://uptime.example.test/status", saved("uptime_kuma")["base_url"]
  end
end
