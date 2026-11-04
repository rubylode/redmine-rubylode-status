# Rubylode Status: one page for the status blocks of the Rubylode plugins, for Redmine
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative "../test_helper"

class RubylodeStatus::StatusJsonTest < Redmine::IntegrationTest
  include RubylodeStatusTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  TOKEN = "status-token-for-tests-6f1c"

  setup do
    isolate_registry
    configure_plugin
    register_stub_widget("beszel", title: "Servers", state: "warning", summary: "1 of 2 busy",
                                   items: [{ name: "web-1", state: "warning", detail: "CPU 91%" }])
    register_stub_widget("windmill", title: "Windmill", visibility: "admins")
    @saved_token = ENV["STATUS_TOKEN"]
    ENV["STATUS_TOKEN"] = TOKEN
  end

  teardown do
    ENV["STATUS_TOKEN"] = @saved_token
    restore_registry
  end

  def body
    JSON.parse(response.body)
  end

  test "a request without a login or token gets 401 with a JSON error" do
    get "/status.json"

    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert_equal "Sign in, or send a Redmine API key or the status token.", body["error"]
  end

  test "a wrong token gets 401" do
    get "/status.json", headers: { "Authorization" => "Bearer not-the-token" }

    assert_response :unauthorized
  end

  test "a signed-in session gets Redmine's health and the widgets it may see" do
    log_user("jsmith", "jsmith")
    get "/status.json"

    assert_response :success
    assert_equal({ "version" => Redmine::VERSION.to_s, "database" => "ok" }, body["redmine"])
    assert Time.iso8601(body["generated_at"])
    assert_equal [{ "key" => "beszel", "title" => "Servers", "state" => "warning", "summary" => "1 of 2 busy",
                    "items" => [{ "name" => "web-1", "state" => "warning", "detail" => "CPU 91%" }],
                    "path" => "/beszel_status" }],
                 body["widgets"]
  end

  test "an administrator's session also gets the administrators-only widgets" do
    log_user("admin", "admin")
    get "/status.json"

    assert_equal %w[beszel windmill], body["widgets"].map { |widget| widget["key"] }
  end

  test "a Redmine API key works" do
    with_settings rest_api_enabled: "1" do
      get "/status.json", headers: { "X-Redmine-API-Key" => User.find(2).api_key }
    end

    assert_response :success
    assert_equal ["beszel"], body["widgets"].map { |widget| widget["key"] }
  end

  test "the token works as a bearer token and in X-Status-Token, and is never in the body" do
    get "/status.json", headers: { "Authorization" => "Bearer #{TOKEN}" }
    assert_response :success
    assert_equal ["beszel"], body["widgets"].map { |widget| widget["key"] }
    assert_not_includes response.body, TOKEN

    get "/status.json", headers: { "X-Status-Token" => TOKEN }
    assert_response :success
    assert_not_includes response.body, TOKEN
  end

  test "the token works when Redmine requires a login for everything" do
    with_settings login_required: "1" do
      get "/status.json", headers: { "X-Status-Token" => TOKEN }
    end

    assert_response :success
  end

  test "the token does not open the HTML page" do
    get "/status", headers: { "X-Status-Token" => TOKEN }

    assert_redirected_to %r{/login}
  end

  test "no token is accepted when the variable is empty" do
    ENV["STATUS_TOKEN"] = ""
    get "/status.json", headers: { "X-Status-Token" => "" }

    assert_response :unauthorized
  end

  test "a widget that raises is listed as unknown" do
    register_stub_widget("glitchtip") { raise "upstream down" }

    log_user("jsmith", "jsmith")
    get "/status.json"

    glitchtip = body["widgets"].find { |widget| widget["key"] == "glitchtip" }
    assert_equal "unknown", glitchtip["state"]
    assert_equal [], glitchtip["items"]
  end
end
