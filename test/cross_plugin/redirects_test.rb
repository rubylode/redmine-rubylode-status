require_relative "support/cross_plugin_test_helper"

# Area 4: the 1.x paths redirect for one release, and every plugin's own page answers at /status/<key>.
class CrossPluginRedirectsTest < Redmine::IntegrationTest
  include CrossPluginTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  setup do
    Setting.clear_cache
    save_status_settings
    WIDGET_KEYS.each { |key| save_settings(key) }
  end

  OLD_PATHS.each do |old_path, key|
    test "#{old_path} redirects with a 301 to /status/#{key}" do
      get old_path

      assert_response 301
      assert_equal "/status/#{key}", URI.parse(response.location).path
    end

    test "#{old_path} redirects the same way when signed in" do
      log_user("admin", "admin")
      get old_path

      assert_response 301
      assert_equal "/status/#{key}", URI.parse(response.location).path
    end
  end

  WIDGET_KEYS.each do |key|
    test "/status/#{key} renders the plugin's own page with the block title" do
      log_user("admin", "admin")
      get "/status/#{key}"

      assert_response :success
      assert_equal DEFAULT_TITLES.fetch(key), page_document.at_css("#content h2").text.strip
    end

    test "/status/#{key} says Rubylode Status is installed and links to /status" do
      log_user("admin", "admin")
      get "/status/#{key}"

      notice = page_document.at_css("p.rubylode-status-notice")
      assert notice, "no status notice on /status/#{key}"
      assert_match(/Rubylode Status is installed, so this block shows on the Status page\./, notice.text.squish)
      assert_equal "/status", notice.at_css("a")["href"]
      assert_no_match(/Install Rubylode Status/, response.body)
    end

    test "/status/#{key} for a person who may not see the block is refused" do
      save_settings(key, "visibility" => "admins")
      log_user("jsmith", "jsmith")
      get "/status/#{key}"

      assert_response :forbidden
    end
  end

  test "a followed redirect lands on the plugin's page" do
    log_user("admin", "admin")
    get "/glitchtip_errors"
    follow_redirect!

    assert_response :success
    assert_equal "/status/glitchtip", path
  end
end
