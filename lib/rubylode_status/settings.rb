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

module RubylodeStatus
  # The plugin's settings, read with their defaults and kept to sensible values. The token itself is not among them:
  # only the NAME of the environment variable that holds it is a setting.
  class Settings
    PLUGIN_ID = :redmine_rubylode_status

    DEFAULTS = {
      "menu_label" => "Status",
      "timeout_seconds" => "5",
      "token_environment_variable" => "STATUS_TOKEN",
      "widgets" => {}
    }.freeze

    # The token is only ever read from a variable with this prefix, so the setting cannot point the plugin at
    # Redmine's own secrets (SECRET_KEY_BASE, the database password and so on).
    ENVIRONMENT_VARIABLE_PATTERN = /\ASTATUS_[A-Z0-9_]*\z/
    COLUMNS = %w[left right].freeze
    MINIMUM_TIMEOUT_SECONDS = 1
    MAXIMUM_TIMEOUT_SECONDS = 60

    # Where one widget goes on the page. A position of nil means "after the numbered ones".
    Layout = Struct.new(:position, :shown, :column, keyword_init: true) do
      def shown?
        shown
      end
    end

    def self.current
      new(Setting.send(:"plugin_#{PLUGIN_ID}"))
    end

    def initialize(raw_settings = {})
      @settings = DEFAULTS.merge((raw_settings || {}).to_h.stringify_keys.compact)
    end

    def menu_label
      label = @settings["menu_label"].to_s.strip
      label.empty? ? DEFAULTS["menu_label"] : label
    end

    def timeout_seconds
      value = Integer(@settings["timeout_seconds"].to_s.strip, exception: false) || DEFAULTS["timeout_seconds"].to_i
      value.clamp(MINIMUM_TIMEOUT_SECONDS, MAXIMUM_TIMEOUT_SECONDS)
    end

    # The saved name when it is allowed, the default when the setting is empty, nil when it is not allowed:
    # nil means no token, and nothing is read from the environment.
    def token_environment_variable
      name = @settings["token_environment_variable"].to_s.strip
      name = DEFAULTS["token_environment_variable"] if name.empty?
      name.match?(ENVIRONMENT_VARIABLE_PATTERN) ? name : nil
    end

    # The token from the environment, or nil when the variable is missing, empty or not allowed.
    def token
      name = token_environment_variable
      return nil unless name

      value = ENV[name].to_s
      value.empty? ? nil : value
    end

    def token_variable_set?
      !token.nil?
    end

    def layout_for(key)
      values = widget_settings[key.to_s] || {}
      values = values.to_h.stringify_keys
      Layout.new(position: position_from(values["position"]),
                 shown: values.fetch("shown", "1").to_s != "0",
                 column: COLUMNS.include?(values["column"].to_s) ? values["column"].to_s : COLUMNS.first)
    end

    private

    def widget_settings
      widgets = @settings["widgets"]
      widgets.respond_to?(:to_h) ? widgets.to_h.stringify_keys : {}
    end

    def position_from(value)
      Integer(value.to_s.strip, exception: false)
    end
  end
end
