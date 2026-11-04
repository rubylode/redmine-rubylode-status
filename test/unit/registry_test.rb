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

class RubylodeStatus::RegistryTest < ActiveSupport::TestCase
  include RubylodeStatusTestHelpers

  setup { isolate_registry }
  teardown { restore_registry }

  test "a registered widget is listed with its key, title, path and partial" do
    RubylodeStatus::Registry.register(key: "beszel", title: "Servers", path: "/status/beszel",
                                      data: -> { { state: "ok" } }, partial: "rubylode_beszel/status")

    widget = RubylodeStatus::Registry.find("beszel")
    assert_equal "beszel", widget.key
    assert_equal "Servers", widget.title
    assert_equal "/status/beszel", widget.path
    assert_equal "rubylode_beszel/status", widget.partial
    assert_equal "logged_in", widget.visibility
  end

  test "widgets keep the order they were registered in" do
    register_stub_widget("windmill")
    register_stub_widget("beszel")
    register_stub_widget("glitchtip")

    assert_equal %w[windmill beszel glitchtip], RubylodeStatus::Registry.widgets.map(&:key)
  end

  test "registering the same key again replaces the widget and keeps its place" do
    register_stub_widget("beszel", title: "Servers")
    register_stub_widget("glitchtip")
    register_stub_widget("beszel", title: "Machines")

    assert_equal %w[beszel glitchtip], RubylodeStatus::Registry.widgets.map(&:key)
    assert_equal "Machines", RubylodeStatus::Registry.find("beszel").title
  end

  test "a title, path and visibility given as callables are read each time" do
    title = "Servers"
    level = "logged_in"
    RubylodeStatus::Registry.register(key: "beszel", title: -> { title }, path: -> { "/beszel_status" },
                                      data: -> { {} }, visibility: -> { level })
    widget = RubylodeStatus::Registry.find("beszel")

    title = "Machines"
    level = "admins"
    assert_equal "Machines", widget.title
    assert_equal "/beszel_status", widget.path
    assert_equal "admins", widget.visibility
  end

  test "an unknown visibility counts as administrators only" do
    register_stub_widget("beszel", visibility: "everyone")

    assert_equal "admins", RubylodeStatus::Registry.find("beszel").visibility
  end

  test "a registration without a callable for data is refused" do
    assert_raises(ArgumentError) do
      RubylodeStatus::Registry.register(key: "beszel", title: "Servers", path: "/beszel_status", data: { state: "ok" })
    end
  end

  test "a key that is not a short name is refused" do
    assert_raises(ArgumentError) do
      RubylodeStatus::Registry.register(key: "Uptime Kuma", title: "Services", path: "/x", data: -> { {} })
    end
  end

  test "unregister removes the widget" do
    register_stub_widget("beszel")
    RubylodeStatus::Registry.unregister("beszel")

    assert_nil RubylodeStatus::Registry.find("beszel")
    assert_empty RubylodeStatus::Registry.widgets
  end

  # The snippet from docs/widget-contract.md. After boot (a code reload in development) the block runs at once.
  test "the documented snippet registers a widget after Redmine has started" do
    Rails.application.config.after_initialize do
      RubylodeStatus::Registry.register(key: "uptime_kuma", title: "Services", path: "/uptime_kuma_status",
                                        data: -> { { state: "ok" } }) if defined?(RubylodeStatus::Registry)
    end

    assert_equal ["uptime_kuma"], RubylodeStatus::Registry.widgets.map(&:key)
  end
end
