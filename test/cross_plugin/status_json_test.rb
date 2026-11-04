require_relative "support/cross_plugin_test_helper"

# Area 5: /status.json answers only to a signed-in session, an API key or the status token, and lists the four widgets.
class CrossPluginStatusJsonTest < Redmine::IntegrationTest
  include CrossPluginTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  TOKEN = ENV.fetch("STATUS_TOKEN")
  WIDGET_JSON_KEYS = %w[items key path state summary title].freeze

  setup do
    Setting.clear_cache
    Rails.cache.clear
    Setting.rest_api_enabled = "1"
    save_status_settings
    WIDGET_KEYS.each { |key| save_settings(key) }
  end

  def body = JSON.parse(response.body)

  def api_key_for(login) = User.find_by!(login: login).api_key

  test "STATUS_TOKEN is set in the container, and the setting names it" do
    assert_equal "STATUS_TOKEN", RubylodeStatus::Settings.current.token_environment_variable
    assert_equal TOKEN, RubylodeStatus::Settings.current.token
  end

  test "without credentials the answer is 401 with a JSON error" do
    get "/status.json"

    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert body["error"].present?
  end

  test "a wrong token is 401" do
    get "/status.json", headers: { "Authorization" => "Bearer nope" }

    assert_response :unauthorized
  end

  test "an API key gets 200 with Redmine's health and the four widgets" do
    get "/status.json", headers: { "X-Redmine-API-Key" => api_key_for("admin") }

    assert_response :success
    assert_equal Redmine::VERSION.to_s, body.dig("redmine", "version")
    assert_equal "ok", body.dig("redmine", "database")
    assert_equal WIDGET_KEYS, body["widgets"].map { |widget| widget["key"] }
    assert_equal ["Servers", "Errors", "Services", "Windmill"], body["widgets"].map { |widget| widget["title"] }
    body["widgets"].each do |widget|
      assert_equal WIDGET_JSON_KEYS, widget.keys.sort, widget["key"]
      assert_equal "unknown", widget["state"], widget["key"]
      assert widget["summary"].present?, widget["key"]
      assert_kind_of Array, widget["items"], widget["key"]
      assert_equal "/status/#{widget['key']}", widget["path"]
    end
  end

  test "the token in an Authorization Bearer header gets 200" do
    get "/status.json", headers: { "Authorization" => "Bearer #{TOKEN}" }

    assert_response :success
    assert_equal WIDGET_KEYS, body["widgets"].map { |widget| widget["key"] }
    assert body["generated_at"].present?
  end

  test "the token in an X-Status-Token header gets 200" do
    get "/status.json", headers: { "X-Status-Token" => TOKEN }

    assert_response :success
  end

  test "the token in the address is not accepted" do
    get "/status.json?token=#{TOKEN}"

    assert_response :unauthorized
  end

  test "the token holder never sees an administrators-only block, an administrator's key does" do
    save_settings("windmill", "visibility" => "admins")

    get "/status.json", headers: { "X-Status-Token" => TOKEN }
    assert_equal %w[beszel glitchtip uptime_kuma], body["widgets"].map { |widget| widget["key"] }

    get "/status.json", headers: { "X-Redmine-API-Key" => api_key_for("admin") }
    assert_equal WIDGET_KEYS, body["widgets"].map { |widget| widget["key"] }

    get "/status.json", headers: { "X-Redmine-API-Key" => api_key_for("jsmith") }
    assert_equal %w[beszel glitchtip uptime_kuma], body["widgets"].map { |widget| widget["key"] }
  end

  test "the token never appears in any body" do
    bodies = []
    get "/status.json"
    bodies << response.body
    get "/status.json", headers: { "Authorization" => "Bearer #{TOKEN}" }
    bodies << response.body
    get "/status.json", headers: { "X-Status-Token" => "wrong-#{TOKEN}" }
    bodies << response.body
    log_user("admin", "admin")
    get "/status"
    bodies << response.body
    get "/settings/plugin/redmine_rubylode_status"
    bodies << response.body
    WIDGET_KEYS.each do |key|
      get "/status/#{key}"
      bodies << response.body
      get "/settings/plugin/redmine_rubylode_#{key}"
      bodies << response.body
    end

    bodies.each { |text| assert_not_includes text, TOKEN }
  end
end
