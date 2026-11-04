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

require File.expand_path("../../../test/test_helper", __dir__)
require "logger"
require "stringio"

# Views that only the tests use: a sample partial a widget can ask for.
RubylodeStatusController.prepend_view_path(File.expand_path("fixtures/views", __dir__))

module RubylodeStatusTestHelpers
  PLUGIN_ID = RubylodeStatus::Settings::PLUGIN_ID

  # Each test starts with an empty registry and gets the original one back afterwards.
  def isolate_registry
    @saved_widgets = RubylodeStatus::Registry.widgets
    RubylodeStatus::Registry.clear
  end

  def restore_registry
    RubylodeStatus::Registry.restore(@saved_widgets)
  end

  def configure_plugin(overrides = {})
    settings = RubylodeStatus::Settings::DEFAULTS.merge(overrides.transform_keys(&:to_s))
    Setting.send(:"plugin_#{PLUGIN_ID}=", settings)
  end

  # A widget the way a sibling plugin registers one, with fixed data.
  def register_stub_widget(key, title: key.to_s.capitalize, state: "ok", summary: "All good",
                           items: [], visibility: "logged_in", partial: nil, &data)
    data ||= -> { { state: state, summary: summary, items: items } }
    RubylodeStatus::Registry.register(key: key, title: title, path: "/#{key}_status", data: data,
                                      partial: partial, visibility: visibility)
  end

  # Sets environment variables for the length of the block, then puts the old values back.
  def with_environment(values)
    saved = values.keys.to_h { |name| [name, ENV[name]] }
    values.each { |name, value| ENV[name] = value }
    yield
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  # Runs the block with a logger writing into a string, and returns that string.
  def captured_log
    output = StringIO.new
    logger = Logger.new(output)
    yield logger
    output.string
  end
end
