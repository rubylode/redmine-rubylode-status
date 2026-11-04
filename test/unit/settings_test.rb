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

class RubylodeStatus::SettingsTest < ActiveSupport::TestCase
  def settings(values = {})
    RubylodeStatus::Settings.new(values)
  end

  test "the menu label defaults to Status, also when it is blank" do
    assert_equal "Status", settings.menu_label
    assert_equal "Status", settings("menu_label" => "  ").menu_label
    assert_equal "Health", settings("menu_label" => " Health ").menu_label
  end

  test "the timeout is a whole number from 1 to 60 seconds" do
    assert_equal 5, settings.timeout_seconds
    assert_equal 1, settings("timeout_seconds" => "0").timeout_seconds
    assert_equal 60, settings("timeout_seconds" => "600").timeout_seconds
    assert_equal 5, settings("timeout_seconds" => "soon").timeout_seconds
  end

  test "the token variable must start with STATUS_" do
    assert_equal "STATUS_TOKEN", settings.token_environment_variable
    assert_equal "STATUS_MONITOR_TOKEN", settings("token_environment_variable" => "STATUS_MONITOR_TOKEN").token_environment_variable
    assert_equal "STATUS_TOKEN", settings("token_environment_variable" => "").token_environment_variable
    assert_nil settings("token_environment_variable" => "SECRET_KEY_BASE").token_environment_variable
  end

  test "the token is read from the variable, and a variable that is not allowed gives no token" do
    saved = ENV.values_at("STATUS_TOKEN", "OTHER_TOKEN")
    ENV["STATUS_TOKEN"] = "status-token-for-tests"
    ENV["OTHER_TOKEN"] = "other-token-for-tests"

    assert_equal "status-token-for-tests", settings.token
    assert_nil settings("token_environment_variable" => "OTHER_TOKEN").token
    ENV["STATUS_TOKEN"] = ""
    assert_nil settings.token
  ensure
    ENV["STATUS_TOKEN"], ENV["OTHER_TOKEN"] = saved
  end

  test "a widget without layout settings is shown in the left column with no position" do
    layout = settings.layout_for("beszel")

    assert layout.shown?
    assert_equal "left", layout.column
    assert_nil layout.position
  end

  test "a widget's layout comes from the saved form values" do
    values = { "widgets" => { "beszel" => { "position" => "2", "shown" => "0", "column" => "right" } } }
    layout = settings(values).layout_for("beszel")

    refute layout.shown?
    assert_equal "right", layout.column
    assert_equal 2, layout.position
  end

  test "an unknown column means left, and a blank position means none" do
    values = { "widgets" => { "beszel" => { "position" => "", "shown" => "1", "column" => "middle" } } }
    layout = settings(values).layout_for("beszel")

    assert_equal "left", layout.column
    assert_nil layout.position
  end
end
