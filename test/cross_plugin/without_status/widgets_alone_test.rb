require_relative "../support/cross_plugin_test_helper"

# Area 6: the four widget plugins in a Redmine that has no Status plugin. Each still boots, serves its own page at
# /status/<key>, offers a top menu item through its own setting, and says that Rubylode Status would put it with the others.
class CrossPluginWidgetsAloneTest < Redmine::IntegrationTest
  include CrossPluginTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  CONFIGURED_SETTINGS = {
    "beszel" => { "base_url" => "http://127.0.0.1:9" },
    "glitchtip" => { "base_url" => "http://127.0.0.1:9", "organization_slug" => "acme" },
    "uptime_kuma" => { "base_url" => "http://127.0.0.1:9", "services" => "Site | https://example.test | x | Site" },
    "windmill" => { "base_url" => "http://127.0.0.1:9", "workspace_id" => "main" }
  }.freeze

  setup do
    Setting.clear_cache
    Rails.cache.clear
    WIDGET_KEYS.each { |key| save_settings(key, CONFIGURED_SETTINGS.fetch(key)) }
  end

  def menu_captions
    page_document.css("#top-menu .top-menu__links a").map { |link| link.text.strip }
  end

  test "this run really has no Status plugin" do
    assert_not Redmine::Plugin.installed?(:redmine_rubylode_status)
    assert_not defined?(RubylodeStatus::Registry)
  end

  test "all four widget plugins are installed at 2.0.0" do
    WIDGET_KEYS.each do |key|
      assert Redmine::Plugin.installed?(:"redmine_rubylode_#{key}"), key
      assert_equal "2.0.0", Redmine::Plugin.find(:"redmine_rubylode_#{key}").version, key
    end
  end

  test "there is no /status page" do
    log_user("admin", "admin")
    get "/status"

    assert_response :not_found
  end

  WIDGET_KEYS.each do |key|
    test "#{key}: its own page at /status/#{key} answers with the block title" do
      log_user("admin", "admin")
      get "/status/#{key}"

      assert_response :success
      assert_equal DEFAULT_TITLES.fetch(key), page_document.at_css("#content h2").text.strip
    end

    test "#{key}: its own page tells the reader to install Rubylode Status" do
      log_user("admin", "admin")
      get "/status/#{key}"

      notice = page_document.at_css("p.rubylode-status-notice")
      assert notice, "no notice on /status/#{key}"
      assert_equal NOTICE_MISSING, notice.text.squish
      assert_equal "https://github.com/rubylode/redmine-rubylode-status", notice.at_css("a")["href"]
    end

    test "#{key}: its settings page shows the same notice and the Show in the top menu setting" do
      log_user("admin", "admin")
      get "/settings/plugin/redmine_rubylode_#{key}"

      assert_response :success
      notice = page_document.at_css("p.rubylode-status-notice")
      assert notice, "no notice on the settings page"
      assert_equal NOTICE_MISSING, notice.text.squish
      checkbox = page_document.at_css("input[type=checkbox][name='settings[show_in_top_menu]']")
      assert checkbox, "the show_in_top_menu check box is not on the settings page"
      assert_nil checkbox["checked"]
    end

    test "#{key}: with show_in_top_menu on, its menu item shows with the block title" do
      save_settings(key, CONFIGURED_SETTINGS.fetch(key).merge("show_in_top_menu" => "1", "block_title" => "Title for #{key}"))
      log_user("admin", "admin")
      get "/"

      assert_includes menu_captions, "Title for #{key}"
      assert_equal "/status/#{key}", page_document.at_css("#top-menu .top-menu__links a[href='/status/#{key}']")["href"]
      assert_equal 1, (menu_captions - BASE_MENU).size
    end

    test "#{key}: with show_in_top_menu on and the default title, the caption is #{DEFAULT_TITLES.fetch(key)}" do
      save_settings(key, CONFIGURED_SETTINGS.fetch(key).merge("show_in_top_menu" => "1"))
      log_user("admin", "admin")
      get "/"

      assert_includes menu_captions, DEFAULT_TITLES.fetch(key)
    end

    test "#{key}: with show_in_top_menu off there is no menu item" do
      log_user("admin", "admin")
      get "/"

      assert_empty menu_captions - BASE_MENU
    end

    test "#{key}: the checked box is saved from the settings form" do
      log_user("admin", "admin")
      post "/settings/plugin/redmine_rubylode_#{key}", params: { settings: CONFIGURED_SETTINGS.fetch(key).merge("show_in_top_menu" => "1") }

      assert_equal "1", Setting.send(:"plugin_redmine_rubylode_#{key}").to_h.stringify_keys["show_in_top_menu"]
      get "/"
      assert_includes menu_captions, DEFAULT_TITLES.fetch(key)
    end
  end

  test "all four menu items at once, in plugin order, none of the old captions" do
    WIDGET_KEYS.each { |key| save_settings(key, CONFIGURED_SETTINGS.fetch(key).merge("show_in_top_menu" => "1")) }
    log_user("admin", "admin")
    get "/"

    assert_equal 4, (menu_captions - BASE_MENU).size
    OLD_MENU_CAPTIONS.each { |caption| assert_not_includes menu_captions, caption } unless DEFAULT_TITLES.values.intersect?(OLD_MENU_CAPTIONS)
    assert_not_includes menu_captions, "Service status"
    assert_not_includes menu_captions, "Windmill status"
  end

  test "a person who may not see a block gets no menu item for it" do
    save_settings("beszel", CONFIGURED_SETTINGS.fetch("beszel").merge("show_in_top_menu" => "1", "visibility" => "admins"))
    log_user("jsmith", "jsmith")
    get "/"

    assert_not_includes menu_captions, "Servers"
  end
end
