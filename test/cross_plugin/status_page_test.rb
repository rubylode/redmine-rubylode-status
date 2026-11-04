require_relative "support/cross_plugin_test_helper"

# Area 3: /status draws the four widgets in the default order, with the default titles, and survives an unset widget.
class CrossPluginStatusPageTest < Redmine::IntegrationTest
  include CrossPluginTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  setup do
    Setting.clear_cache
    Rails.cache.clear
    save_status_settings
    WIDGET_KEYS.each { |key| save_settings(key) }
  end

  test "the four widgets are listed in the default order with their default titles" do
    log_user("admin", "admin")
    get "/status"

    assert_response :success
    assert_equal WIDGET_KEYS, status_widget_keys_on_page
    titles = page_document.css("div.rubylode-status-widget > h3 > a").map { |link| link.text.strip }
    assert_equal ["Servers", "Errors", "Services", "Windmill"], titles
    assert_equal WIDGET_KEYS.map { |key| "/status/#{key}" }, page_document.css("div.rubylode-status-widget > h3 > a").map { |link| link["href"] }
  end

  test "with nothing configured every widget shows Unknown and a not set up summary, and the page still renders" do
    log_user("admin", "admin")
    get "/status"

    assert_response :success
    WIDGET_KEYS.each do |key|
      widget = page_document.at_css("#rubylode-status-widget-#{key}")
      assert widget.matches?(".rubylode-status-state-unknown"), "#{key} is not unknown"
      assert_equal "Unknown", widget.at_css("h3 .rubylode-status-state-label").text.strip
      assert_match(/not set up/i, widget.at_css(".rubylode-status-summary").text, key)
      assert_nil widget.at_css(".rubylode-status-state-label + p.error, .flash.error"), key
    end
    assert_no_match(/could not be (loaded|drawn)/, response.body)
  end

  test "a changed block title shows on the page" do
    save_settings("beszel", "block_title" => "Machines")
    log_user("admin", "admin")
    get "/status"

    assert_equal "Machines", page_document.at_css("#rubylode-status-widget-beszel > h3 > a").text.strip
  end

  test "a widget set to administrators only is hidden from other people and shown to administrators" do
    save_settings("windmill", "visibility" => "admins")
    log_user("jsmith", "jsmith")
    get "/status"
    assert_response :success
    assert_equal %w[beszel glitchtip uptime_kuma], status_widget_keys_on_page

    post "/logout"
    log_user("admin", "admin")
    get "/status"
    assert_equal WIDGET_KEYS, status_widget_keys_on_page
  end

  test "when every widget is administrators only a signed-in person gets 403" do
    WIDGET_KEYS.each { |key| save_settings(key, "visibility" => "admins") }
    log_user("jsmith", "jsmith")
    get "/status"

    assert_response :forbidden
  end

  test "an unsigned visitor is sent to the login page" do
    get "/status"

    assert_response :redirect
    assert_match %r{/login}, response.location
  end
end
