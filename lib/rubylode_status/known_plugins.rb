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
  # The Rubylode plugins that register a block, named on the empty page and in the README.
  module KnownPlugins
    Plugin = Struct.new(:name, :shows, :url, keyword_init: true)

    LIST = [
      Plugin.new(name: "Rubylode Beszel", shows: "servers from a Beszel hub",
                 url: "https://github.com/rubylode/redmine-rubylode-beszel"),
      Plugin.new(name: "Rubylode GlitchTip", shows: "recent GlitchTip errors",
                 url: "https://github.com/rubylode/redmine-rubylode-glitchtip"),
      Plugin.new(name: "Rubylode Uptime Kuma", shows: "services from Uptime Kuma",
                 url: "https://github.com/rubylode/redmine-rubylode-uptime-kuma"),
      Plugin.new(name: "Rubylode Windmill", shows: "failed runs and schedules from Windmill",
                 url: "https://github.com/rubylode/redmine-rubylode-windmill")
    ].freeze
  end
end
