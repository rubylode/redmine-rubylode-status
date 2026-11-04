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

class RubylodeStatus::TopMenuTest < Redmine::IntegrationTest
  include RubylodeStatusTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles

  setup do
    isolate_registry
    configure_plugin
  end

  teardown { restore_registry }

  test "the top menu links to the Status page for someone who may see a widget" do
    register_stub_widget("beszel")

    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_select "#top-menu a.rubylode-status[href='/status']", text: "Status"
  end

  test "the link is named by the menu label setting" do
    register_stub_widget("beszel")
    configure_plugin("menu_label" => "Health")

    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_select "#top-menu a.rubylode-status", text: "Health"
  end

  test "there is no link when nothing is registered" do
    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_select "#top-menu a.rubylode-status", count: 0
  end

  test "there is no link for someone who may see none of the widgets" do
    register_stub_widget("windmill", visibility: "admins")

    log_user("jsmith", "jsmith")
    get "/my/page"
    assert_select "#top-menu a.rubylode-status", count: 0

    reset!

    log_user("admin", "admin")
    get "/my/page"
    assert_select "#top-menu a.rubylode-status", count: 1
  end

  test "there is no link for a hidden widget" do
    register_stub_widget("beszel")
    configure_plugin("widgets" => { "beszel" => { "shown" => "0" } })

    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_select "#top-menu a.rubylode-status", count: 0
  end
end
