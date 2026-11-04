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
  # One registered widget. Title, path and visibility may be callables, so a plugin can hand over its own settings
  # without the Status plugin reading them: they are asked each time the page is drawn.
  class Widget
    VISIBILITIES = %w[logged_in admins].freeze

    attr_reader :key, :partial, :data

    def initialize(key:, title:, path:, data:, partial:, visibility:)
      @key = key
      @title = title
      @path = path
      @data = data
      @partial = partial.presence&.to_s
      @visibility = visibility
    end

    def title
      resolve(@title).to_s
    end

    def path
      resolve(@path).to_s
    end

    # "logged_in" or "admins". Anything else counts as administrators only, so a mistake hides a block rather than
    # showing it to too many people.
    def visibility
      level = resolve(@visibility).to_s
      VISIBILITIES.include?(level) ? level : "admins"
    end

    private

    def resolve(value)
      value.respond_to?(:call) ? value.call : value
    end
  end
end
