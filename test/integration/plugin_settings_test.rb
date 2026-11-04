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

class RubylodeStatus::PluginSettingsTest < Redmine::IntegrationTest
  include RubylodeStatusTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  setup do
    isolate_registry
    configure_plugin
    log_user("admin", "admin")
  end

  teardown { restore_registry }

  def settings_path
    "/settings/plugin/#{PLUGIN_ID}"
  end

  test "the settings page lists every registered widget with its order, switch and column" do
    register_stub_widget("beszel", title: "Servers")
    register_stub_widget("windmill", title: "Windmill", visibility: "admins")

    get settings_path

    assert_response :success
    assert_select "input[name='settings[menu_label]'][value='Status']"
    assert_select "tr#rubylode-status-layout-beszel" do
      assert_select "td", text: "Servers"
      assert_select "input[name='settings[widgets][beszel][position]']"
      assert_select "input[type=checkbox][name='settings[widgets][beszel][shown]'][checked]"
      assert_select "select[name='settings[widgets][beszel][column]'] option[selected]", text: "Left"
    end
    assert_select "tr#rubylode-status-layout-windmill"
  end

  test "with nothing registered the settings page says so" do
    get settings_path

    assert_select ".rubylode-status-empty", text: /No status blocks are registered yet/
  end

  test "saving the form stores the menu label and the layout" do
    register_stub_widget("beszel")

    post settings_path, params: { settings: { menu_label: "Health", timeout_seconds: "3",
                                              token_environment_variable: "STATUS_TOKEN",
                                              widgets: { beszel: { position: "2", shown: "0", column: "right" } } } }

    settings = RubylodeStatus::Settings.current
    assert_equal "Health", settings.menu_label
    assert_equal 3, settings.timeout_seconds
    layout = settings.layout_for("beszel")
    assert_equal 2, layout.position
    refute layout.shown?
    assert_equal "right", layout.column
  end

  test "the settings page says whether the token variable is set and never shows its value" do
    with_environment("STATUS_TOKEN" => "status-token-for-tests") do
      get settings_path

      assert_select ".rubylode-status-token-state", text: "The variable is set."
      assert_no_match "status-token-for-tests", response.body
    end

    with_environment("STATUS_TOKEN" => nil) do
      get settings_path

      assert_select ".rubylode-status-token-state", text: /The variable is not set/
    end
  end
end
