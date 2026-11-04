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

class RubylodeStatus::WidgetStatusTest < ActiveSupport::TestCase
  include RubylodeStatusTestHelpers

  setup { isolate_registry }
  teardown { restore_registry }

  def fetch(widget, timeout_seconds: 5, logger: Rails.logger)
    RubylodeStatus::WidgetStatus.fetch(widget, timeout_seconds: timeout_seconds, logger: logger)
  end

  test "the state, summary and items come from the widget's data" do
    widget = register_stub_widget("beszel", state: "warning", summary: "1 of 3 busy",
                                            items: [{ name: "web-1", state: "warning", detail: "CPU 91%" }])

    status = fetch(widget)

    assert_equal "warning", status.state
    assert_equal "1 of 3 busy", status.summary
    assert_equal [{ name: "web-1", state: "warning", detail: "CPU 91%" }], status.items
    refute status.failed?
  end

  test "string keys work as well as symbols" do
    widget = register_stub_widget("beszel") { { "state" => "down", "summary" => "db-1 down", "items" => [{ "name" => "db-1", "state" => "down" }] } }

    status = fetch(widget)

    assert_equal "down", status.state
    assert_equal [{ name: "db-1", state: "down", detail: nil }], status.items
  end

  test "a state that is not one of the four becomes unknown, for the widget and for an item" do
    widget = register_stub_widget("beszel") { { state: "green", summary: "Fine", items: [{ name: "web-1", state: "up" }] } }

    status = fetch(widget)

    assert_equal "unknown", status.state
    assert_equal "unknown", status.items.first[:state]
  end

  test "a widget that raises shows as unknown with a short message, and the error goes to the log" do
    widget = register_stub_widget("beszel") { raise "connection refused to https://user:secret@beszel.example.com" }

    status = nil
    log = captured_log { |logger| status = fetch(widget, logger: logger) }

    assert_equal "unknown", status.state
    assert_equal "This block could not be loaded. The error is in the Redmine log.", status.summary
    assert_empty status.items
    assert status.failed?
    assert_includes log, "connection refused"
    assert_includes log, "beszel"
  end

  test "a widget that takes too long shows as unknown" do
    widget = register_stub_widget("beszel") do
      sleep 2
      { state: "ok" }
    end

    status = fetch(widget, timeout_seconds: 0.1)

    assert_equal "unknown", status.state
    assert_equal "This block did not answer within 0.1 seconds.", status.summary
  end

  test "a widget that returns something other than a hash shows as unknown" do
    widget = register_stub_widget("beszel") { "all good" }

    status = fetch(widget)

    assert_equal "unknown", status.state
    assert_equal "This block returned nothing to show.", status.summary
  end

  test "a summary is kept to one line" do
    widget = register_stub_widget("beszel") { { state: "ok", summary: "First line\nSecond line" } }

    assert_equal "First line Second line", fetch(widget).summary
  end

  test "to_h is the shape /status.json lists" do
    widget = register_stub_widget("beszel", title: "Servers", state: "ok", summary: "3 up",
                                            items: [{ name: "web-1", state: "ok", detail: "" }])

    assert_equal({ key: "beszel", title: "Servers", state: "ok", summary: "3 up",
                   items: [{ name: "web-1", state: "ok", detail: "" }], path: "/beszel_status" },
                 fetch(widget).to_h)
  end
end
