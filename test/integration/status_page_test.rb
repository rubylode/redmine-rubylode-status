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

class RubylodeStatus::StatusPageTest < Redmine::IntegrationTest
  include RubylodeStatusTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  setup do
    isolate_registry
    configure_plugin
  end

  teardown { restore_registry }

  test "a visitor who is not signed in is sent to the sign-in page" do
    register_stub_widget("beszel")

    get "/status"

    assert_redirected_to %r{/login}
  end

  test "the page shows each registered widget with its title, state, summary and items" do
    register_stub_widget("beszel", title: "Servers", state: "down", summary: "1 of 2 down",
                                   items: [{ name: "db-1", state: "down", detail: "No answer for 5 minutes" },
                                           { name: "web-1", state: "ok" }])
    register_stub_widget("glitchtip", title: "Errors", state: "ok", summary: "No new errors")

    log_user("jsmith", "jsmith")
    get "/status"

    assert_response :success
    assert_select "h2", text: "Status"
    assert_select "#rubylode-status-widget-beszel.rubylode-status-state-down" do
      assert_select "h3 a[href='/beszel_status']", text: "Servers"
      assert_select ".rubylode-status-state-label", text: "Down"
      assert_select ".rubylode-status-summary", text: "1 of 2 down"
      assert_select "li.rubylode-status-state-down", text: /db-1.*No answer for 5 minutes/m
      assert_select "li.rubylode-status-state-ok", text: /web-1/
    end
    assert_select "#rubylode-status-widget-glitchtip .rubylode-status-summary", text: "No new errors"
  end

  test "widgets follow the order and column from the settings, and a hidden one is left out" do
    register_stub_widget("beszel")
    register_stub_widget("glitchtip")
    register_stub_widget("windmill")
    configure_plugin("widgets" => { "windmill" => { "position" => "1", "column" => "right" },
                                    "glitchtip" => { "shown" => "0" } })

    log_user("jsmith", "jsmith")
    get "/status"

    assert_select ".rubylode-status-column-right #rubylode-status-widget-windmill"
    assert_select ".rubylode-status-column-left #rubylode-status-widget-beszel"
    assert_select "#rubylode-status-widget-glitchtip", count: 0
  end

  test "an administrators-only widget is shown to administrators and to nobody else" do
    register_stub_widget("beszel")
    register_stub_widget("windmill", visibility: "admins")

    log_user("jsmith", "jsmith")
    get "/status"
    assert_select "#rubylode-status-widget-beszel"
    assert_select "#rubylode-status-widget-windmill", count: 0

    reset!

    log_user("admin", "admin")
    get "/status"
    assert_select "#rubylode-status-widget-windmill"
  end

  test "someone who may see none of the registered widgets is refused" do
    register_stub_widget("windmill", visibility: "admins")

    log_user("jsmith", "jsmith")
    get "/status"

    assert_response :forbidden
  end

  test "with nothing registered the page says so and names the plugins that add a block" do
    log_user("jsmith", "jsmith")
    get "/status"

    assert_response :success
    assert_select ".rubylode-status-empty", text: /No status blocks are registered yet/
    assert_select ".rubylode-status-empty a[href='https://github.com/rubylode/redmine-rubylode-beszel']", text: "Rubylode Beszel"
    assert_select ".rubylode-status-empty a[href='https://github.com/rubylode/redmine-rubylode-glitchtip']", text: "Rubylode GlitchTip"
    assert_select ".rubylode-status-empty a[href='https://github.com/rubylode/redmine-rubylode-uptime-kuma']", text: "Rubylode Uptime Kuma"
    assert_select ".rubylode-status-empty a[href='https://github.com/rubylode/redmine-rubylode-windmill']", text: "Rubylode Windmill"
  end

  test "a widget that raises shows as unknown and the rest of the page still works" do
    register_stub_widget("beszel") { raise "hub unreachable" }
    register_stub_widget("glitchtip", summary: "No new errors")

    log_user("jsmith", "jsmith")
    get "/status"

    assert_response :success
    assert_select "#rubylode-status-widget-beszel.rubylode-status-state-unknown .rubylode-status-summary",
                  text: "This block could not be loaded. The error is in the Redmine log."
    assert_select "#rubylode-status-widget-glitchtip .rubylode-status-summary", text: "No new errors"
    assert_no_match "hub unreachable", response.body
  end

  test "a widget with a partial draws its body with it" do
    register_stub_widget("beszel", partial: "rubylode_status_test/rich_body",
                                   items: [{ name: "web-1", state: "ok" }]) { { state: "ok", summary: "3 up", chart: "cpu 40%" } }

    log_user("jsmith", "jsmith")
    get "/status"

    assert_select "#rubylode-status-widget-beszel .rich-body", text: "beszel: cpu 40%"
  end

  test "a partial that fails leaves the page standing" do
    register_stub_widget("beszel", partial: "rubylode_status_test/missing_partial")
    register_stub_widget("glitchtip")

    log_user("jsmith", "jsmith")
    get "/status"

    assert_response :success
    assert_select "#rubylode-status-widget-beszel .rubylode-status-drawing-failed",
                  text: "This block could not be drawn. The error is in the Redmine log."
    assert_select "#rubylode-status-widget-glitchtip"
  end
end
