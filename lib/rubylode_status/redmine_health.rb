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
  # Redmine's own part of /status.json: its version and whether the database answers.
  class RedmineHealth
    def initialize(connection: -> { ActiveRecord::Base.connection })
      @connection = connection
    end

    def to_h
      { version: Redmine::VERSION.to_s, database: database_state }
    end

    private

    def database_state
      @connection.call.select_value("SELECT 1")
      "ok"
    rescue StandardError
      "down"
    end
  end
end
