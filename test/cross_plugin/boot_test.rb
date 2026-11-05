require_relative "support/cross_plugin_test_helper"

# Area 1: Redmine starts with all five plugins and the four widgets are in the registry.
class CrossPluginBootTest < ActiveSupport::TestCase
  include CrossPluginTestHelpers

  test "all five plugins are installed" do
    %w[beszel glitchtip uptime_kuma windmill status].each do |short_name|
      assert Redmine::Plugin.installed?(:"redmine_rubylode_#{short_name}"), "redmine_rubylode_#{short_name} is not installed"
    end
  end

  test "every plugin reports a version" do
    %w[beszel glitchtip uptime_kuma windmill status].each do |short_name|
      assert_match(/\A\d+\.\d+\.\d+\z/, Redmine::Plugin.find(:"redmine_rubylode_#{short_name}").version, short_name)
    end
  end

# The brief assumed the four load before status. They do not: "uptime_kuma" and "windmill" sort after "status", so two
# init.rb files run before status and two after. Registration waits for after_initialize, so the order does not matter.
test "plugins load in alphabetical directory order, so beszel and glitchtip load before status and uptime_kuma and windmill after" do
  loaded = Redmine::PluginLoader.directories.map { |directory| File.basename(directory.to_s) }.grep(/rubylode/)
  assert_equal loaded.sort, loaded
  assert_equal %w[redmine_rubylode_beszel redmine_rubylode_glitchtip redmine_rubylode_status redmine_rubylode_uptime_kuma redmine_rubylode_windmill], loaded
end

  test "the registry holds exactly the four widgets, in plugin load order" do
    assert_equal WIDGET_KEYS, RubylodeStatus::Registry.widgets.map(&:key)
  end

  test "each widget registered its own page path, partial and a visibility callable" do
    expected_partials = { "beszel" => "rubylode_beszel/status", "glitchtip" => "rubylode_glitchtip/status",
                          "uptime_kuma" => "rubylode_uptime_kuma/status", "windmill" => "rubylode_windmill/status" }
    RubylodeStatus::Registry.widgets.each do |widget|
      assert_equal "/status/#{widget.key}", widget.path, widget.key
      assert_equal expected_partials.fetch(widget.key), widget.partial, widget.key
    end
  end
end
