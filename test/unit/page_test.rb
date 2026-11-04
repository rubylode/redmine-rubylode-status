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

class RubylodeStatus::PageTest < ActiveSupport::TestCase
  include RubylodeStatusTestHelpers

  setup { isolate_registry }
  teardown { restore_registry }

  def page_for(viewer, widgets: {})
    RubylodeStatus::Page.new(viewer: viewer, settings: RubylodeStatus::Settings.new("widgets" => widgets))
  end

  def member
    RubylodeStatus::Viewer.new(signed_in: true, administrator: false)
  end

  def administrator
    RubylodeStatus::Viewer.new(signed_in: true, administrator: true)
  end

  test "widgets with a position come first, lowest first, then the rest in the order they registered" do
    register_stub_widget("windmill")
    register_stub_widget("beszel")
    register_stub_widget("glitchtip")
    register_stub_widget("uptime_kuma")

    page = page_for(member, widgets: { "glitchtip" => { "position" => "1" }, "uptime_kuma" => { "position" => "2" } })

    assert_equal %w[glitchtip uptime_kuma windmill beszel], page.widgets.map(&:key)
  end

  test "a hidden widget is left out" do
    register_stub_widget("windmill")
    register_stub_widget("beszel")

    page = page_for(member, widgets: { "windmill" => { "shown" => "0" } })

    assert_equal ["beszel"], page.widgets.map(&:key)
  end

  test "an administrators-only widget is left out for everyone else" do
    register_stub_widget("windmill", visibility: "admins")
    register_stub_widget("beszel")

    assert_equal ["beszel"], page_for(member).widgets.map(&:key)
    assert_equal %w[windmill beszel], page_for(administrator).widgets.map(&:key)
    assert_empty page_for(RubylodeStatus::Viewer.for_user(User.anonymous)).widgets
  end

  test "the holder of the status token sees what everyone signed in sees" do
    register_stub_widget("windmill", visibility: "admins")
    register_stub_widget("beszel")

    assert_equal ["beszel"], page_for(RubylodeStatus::Viewer.token_holder).widgets.map(&:key)
  end

  test "the columns split the widgets, and one column is used when nothing is on the right" do
    register_stub_widget("windmill")
    register_stub_widget("beszel")

    one_column = page_for(member)
    two_columns = page_for(member, widgets: { "beszel" => { "column" => "right" } })

    refute one_column.two_columns?
    assert two_columns.two_columns?
    assert_equal ["windmill"], two_columns.left_widgets.map(&:key)
    assert_equal ["beszel"], two_columns.right_widgets.map(&:key)
  end

  test "the page does not ask a widget for its data until the statuses are needed" do
    asked = false
    register_stub_widget("beszel") { asked = true; { state: "ok" } }

    page = page_for(member)
    page.widgets
    refute asked

    page.statuses
    assert asked
  end
end
