require_relative "support/cross_plugin_test_helper"

# Area 8: the four widgets against stub HTTP services that answer like Beszel, GlitchTip, Uptime Kuma and Windmill, so the
# page shows real ok, warning and down states instead of "not set up".
class CrossPluginRealisticDataTest < Redmine::IntegrationTest
  include CrossPluginTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  setup do
    Setting.clear_cache
    @stubs = CrossPluginStubs.start_all
    save_status_settings
    point_widgets_at(@stubs, "uptime_kuma" => {}, "windmill" => { "watched_schedules" => "" })
    healthy_services
    log_user("admin", "admin")
  end

  teardown do
    @stubs.each_value(&:stop)
  end

  def healthy_services
    beszel = @stubs[:beszel]
    beszel.systems = [beszel.system("web-1"), beszel.system("db-1")]
    @stubs[:glitchtip].issues = []
    @stubs[:uptime_kuma].monitors = { "Website" => [true, 120], "Mail" => [true, 80] }
    @stubs[:windmill].failed_jobs = []
  end

  def load_status_page
    get "/status"
    @status_html = response.body
  end

  def widget(key) = Nokogiri::HTML(@status_html).at_css("#rubylode-status-widget-#{key}")

  def state_of(key) = widget(key)["class"][/rubylode-status-state-(\w+)/, 1]

  def summary_of(key) = widget(key).at_css(".rubylode-status-summary").text.squish

  # The plugins draw their own list inside the block, so the items are read from /status.json, which is the contract.
  def item_states(key)
    get "/status.json"
    entry = JSON.parse(response.body)["widgets"].find { |widget| widget["key"] == key }
    entry["items"].to_h { |item| [item["name"], item["state"]] }
  end

  test "everything healthy: all four widgets are ok" do
    load_status_page

    assert_response :success
    WIDGET_KEYS.each { |key| assert_equal "ok", state_of(key), "#{key}: #{summary_of(key)}" }
    assert_equal "2 of 2 servers up", summary_of("beszel")
    assert_equal({ "web-1" => "ok", "db-1" => "ok" }, item_states("beszel"))
    assert_equal({ "Website" => "ok", "Mail" => "ok" }, item_states("uptime_kuma"))
  end

  test "a mixed day: Beszel warns, GlitchTip warns, Uptime Kuma warns, Windmill is down" do
    beszel = @stubs[:beszel]
    beszel.systems = [beszel.system("web-1"), beszel.system("db-1", cpu: 95), beszel.system("backup-1", status: "down")]
    @stubs[:glitchtip].issues = [@stubs[:glitchtip].issue(1, "NoMethodError in OrdersController", count: 40),
                                 @stubs[:glitchtip].issue(2, "Timeout talking to payments", level: "fatal", count: 3)]
    @stubs[:uptime_kuma].monitors = { "Website" => [true, 120], "Mail" => [false, 0] }
    @stubs[:windmill].failed_jobs = [@stubs[:windmill].failed_job("job-1", "f/billing/nightly", error: "connection refused")]

    load_status_page

    assert_equal "warning", state_of("beszel")
    assert_equal "2 of 3 servers up", summary_of("beszel")
    assert_equal({ "backup-1" => "down", "web-1" => "ok", "db-1" => "warning" }.sort.to_h, item_states("beszel").sort.to_h)
    assert_equal "warning", state_of("glitchtip")
    assert_match(/2/, summary_of("glitchtip"))
    assert_equal 2, item_states("glitchtip").size
    assert_equal "warning", state_of("uptime_kuma")
    assert_equal({ "Mail" => "down", "Website" => "ok" }, item_states("uptime_kuma"))
    assert_equal "down", state_of("windmill")
    assert_equal({ "f/billing/nightly" => "down" }, item_states("windmill"))
  end

  test "whole services down: Beszel all down and Uptime Kuma all down are down, an unreachable GlitchTip is down" do
    beszel = @stubs[:beszel]
    beszel.systems = [beszel.system("web-1", status: "down"), beszel.system("db-1", status: "down")]
    @stubs[:uptime_kuma].monitors = { "Website" => [false, 0], "Mail" => [false, 0] }
    @stubs[:glitchtip].response_status = 500

    load_status_page

    assert_equal "down", state_of("beszel")
    assert_equal "down", state_of("uptime_kuma")
    assert_equal "down", state_of("glitchtip")
  end

  test "a hub that refuses the sign-in and a Kuma that answers 500 are unknown and the page still draws all four" do
    @stubs[:beszel].sign_in_status = 401
    @stubs[:uptime_kuma].metrics_status = 500
    @stubs[:windmill].response_status = 500

    load_status_page

    assert_response :success
    assert_equal WIDGET_KEYS, status_widget_keys_on_page
    assert_equal "unknown", state_of("beszel")
    assert_equal "unknown", state_of("uptime_kuma")
    assert_equal "unknown", state_of("windmill")
    assert_equal "ok", state_of("glitchtip")
  end

  test "/status.json carries the same states, summaries, items and paths" do
    @stubs[:uptime_kuma].monitors = { "Website" => [true, 120], "Mail" => [false, 0] }
    @stubs[:windmill].failed_jobs = [@stubs[:windmill].failed_job("job-1", "f/billing/nightly")]

    get "/status.json", headers: { "Authorization" => "Bearer #{ENV.fetch('STATUS_TOKEN')}" }

    assert_response :success
    widgets = JSON.parse(response.body)["widgets"].index_by { |entry| entry["key"] }
    assert_equal %w[ok warning down], [widgets["beszel"]["state"], widgets["uptime_kuma"]["state"], widgets["windmill"]["state"]]
    assert_equal "ok", widgets["glitchtip"]["state"]
    assert_equal [{ "name" => "Mail", "state" => "down" }, { "name" => "Website", "state" => "ok" }],
                 widgets["uptime_kuma"]["items"].map { |item| item.slice("name", "state") }.sort_by { |item| item["name"] }
    assert_equal "/status/windmill", widgets["windmill"]["path"]
  end

  test "each plugin sent its credentials to its own service and nowhere else, and none of them reach a page or the JSON" do
    load_status_page
    page = @status_html
    get "/status.json", headers: { "X-Status-Token" => ENV.fetch("STATUS_TOKEN") }
    json = response.body

    assert(@stubs[:beszel].requests.any? { |request| request[:body].include?("stub@example.test") })
    assert(@stubs[:glitchtip].requests.all? { |request| request[:headers]["authorization"] == "Bearer stub-glitchtip-token" })
    assert(@stubs[:uptime_kuma].requests.all? { |request| request[:headers]["authorization"].to_s.start_with?("Basic ") })
    assert(@stubs[:windmill].requests.all? { |request| request[:headers]["authorization"] == "Bearer stub-windmill-token" })
    assert_equal ["/metrics"], @stubs[:uptime_kuma].requests.map { |request| request[:path] }.uniq
    [page, json].each do |body|
      %w[stub-password stub-glitchtip-token stub-kuma-token stub-windmill-token].each { |secret| assert_not_includes body, secret }
    end
  end

  test "on the Status page each block shows its title once, not a second heading from the plugin's own partial" do
    @stubs[:glitchtip].issues = [@stubs[:glitchtip].issue(1, "Boom")]
    @stubs[:windmill].failed_jobs = [@stubs[:windmill].failed_job("job-1", "f/billing/nightly")]
    load_status_page

    {
      "beszel" => ".rubylode-beszel-title", "glitchtip" => ".rubylode-glitchtip-errors-title",
      "uptime_kuma" => ".rubylode-service-status-title", "windmill" => ".rubylode-windmill-status-title"
    }.each do |key, heading|
      assert_nil widget(key).at_css(heading), "BUG: the #{key} partial repeats the block title inside its Status page block"
    end
  end

  test "the plugin's own page shows the same data as the Status block" do
    @stubs[:uptime_kuma].monitors = { "Website" => [true, 120], "Mail" => [false, 0] }
    get "/status/uptime_kuma"

    assert_response :success
    assert_includes response.body, "Mail"
    assert_includes response.body, "Website"
  end
end
