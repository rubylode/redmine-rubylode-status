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

require "redmine"

Redmine::Plugin.register :redmine_rubylode_status do
  name "Rubylode Status"
  author "Rubylode"
  author_url "https://github.com/rubylode"
  url "https://github.com/rubylode/redmine-rubylode-status"
  description "One Status page and one top menu link for the status blocks of the other Rubylode plugins, plus /status.json"
  version "2.1.0"
  requires_redmine version_or_higher: "7.0.0"

  # Shown to the people who may see at least one registered block. The caption is the menu label setting.
  menu :top_menu, :rubylode_status, { controller: "rubylode_status", action: "index" },
       caption: proc { RubylodeStatus::Settings.current.menu_label },
       if: proc { RubylodeStatus::Page.new(viewer: RubylodeStatus::Viewer.for_user(User.current)).any? }

  settings default: RubylodeStatus::Settings::DEFAULTS, partial: "settings/rubylode_status"
end
