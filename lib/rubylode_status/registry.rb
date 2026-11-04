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
  # The list of widgets other plugins have registered. The Status plugin only draws what is here; it never reads
  # another plugin's settings. docs/widget-contract.md has the snippet a plugin uses to register.
  module Registry
    KEY_PATTERN = /\A[a-z][a-z0-9_]*\z/

    @widgets = {}
    @lock = Mutex.new

    class << self
      # Adds a widget, or replaces the one with the same key and keeps its place. Returns the widget.
      #   key:        the plugin's short name, for example "beszel"
      #   title:      the block title, a string or a callable returning one
      #   path:       the path of the plugin's own page, a string or a callable returning one
      #   data:       a callable returning { state:, summary:, items: [{ name:, state:, detail: }] }
      #   partial:    optional, a partial that draws the body of the block
      #   visibility: "logged_in" (everyone signed in, the default) or "admins", or a callable returning one
      def register(key:, title:, path:, data:, partial: nil, visibility: "logged_in")
        key = key.to_s
        raise ArgumentError, "The key #{key.inspect} must be a short name such as \"uptime_kuma\"." unless key.match?(KEY_PATTERN)
        raise ArgumentError, "The data of #{key} must respond to call." unless data.respond_to?(:call)

        widget = Widget.new(key: key, title: title, path: path, data: data, partial: partial, visibility: visibility)
        @lock.synchronize { @widgets[key] = widget }
        widget
      end

      def unregister(key)
        @lock.synchronize { @widgets.delete(key.to_s) }
      end

      def find(key)
        @widgets[key.to_s]
      end

      # Every registered widget, in the order they were first registered.
      def widgets
        @widgets.values
      end

      def any?
        @widgets.any?
      end

      def clear
        @lock.synchronize { @widgets = {} }
      end

      # Puts back a list taken from widgets, for tests.
      def restore(widgets)
        @lock.synchronize { @widgets = widgets.to_h { |widget| [widget.key, widget] } }
      end
    end
  end
end
