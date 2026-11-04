require_relative "support/cross_plugin_test_helper"

# Area 2: with Status installed the top menu gets exactly one new item, and the widgets' own items stay away.
class CrossPluginMenuTest < Redmine::IntegrationTest
  include CrossPluginTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  setup do
    Setting.clear_cache
    save_status_settings
    # Every widget asks for its own top menu item and is set up enough to show it.
    save_settings("beszel", "base_url" => "http://127.0.0.1:9", "show_in_top_menu" => "1")
    save_settings("glitchtip", "base_url" => "http://127.0.0.1:9", "organization_slug" => "acme", "show_in_top_menu" => "1")
    save_settings("uptime_kuma", "base_url" => "http://127.0.0.1:9", "services" => "Site | https://example.test | x | Site",
                                 "show_in_top_menu" => "1")
    save_settings("windmill", "base_url" => "http://127.0.0.1:9", "workspace_id" => "main", "show_in_top_menu" => "1")
  end

  def menu_captions
    page_document.css("#top-menu .top-menu__links a").map { |link| link.text.strip }
  end

  test "an administrator sees one new item, Status, and no other" do
    log_user("admin", "admin")
    get "/"
    assert_response :success

    assert_equal BASE_MENU + ["Status"], menu_captions.sort_by { |caption| (BASE_MENU + ["Status"]).index(caption) || 99 }
    assert_equal 1, (menu_captions - BASE_MENU).size
    assert_equal "/status", page_document.at_css("#top-menu a.rubylode-status")["href"]
  end

  test "none of the four old items show while Status is installed, even with their show_in_top_menu setting on" do
    log_user("admin", "admin")
    get "/"

    OLD_MENU_CAPTIONS.each { |caption| assert_not_includes menu_captions, caption }
    WIDGET_KEYS.each { |key| assert_nil page_document.at_css("#top-menu a[href='/status/#{key}']"), "#{key} still has its own menu item" }
    assert_nil page_document.at_css("#top-menu a[href='/beszel_status'], #top-menu a[href='/windmill_status'], #top-menu a[href='/service_status']")
  end

  test "the item's label is the Status setting and follows a change" do
    save_status_settings("menu_label" => "Health")
    log_user("admin", "admin")
    get "/"

    assert_includes menu_captions, "Health"
    assert_not_includes menu_captions, "Status"
    assert_equal "/status", page_document.at_css("#top-menu .top-menu__links a.rubylode-status")["href"]

    save_status_settings("menu_label" => "Systems overview")
    get "/"
    assert_includes menu_captions, "Systems overview"
    assert_not_includes menu_captions, "Health"
  end

  test "a person who may see none of the blocks gets no Status item" do
    WIDGET_KEYS.each { |key| save_settings(key, "visibility" => "admins") }
    log_user("jsmith", "jsmith")
    get "/"

    assert_not_includes menu_captions, "Status"
  end

  test "a signed-in person who may see the blocks gets the Status item" do
    log_user("jsmith", "jsmith")
    get "/"

    assert_includes menu_captions, "Status"
  end
end
