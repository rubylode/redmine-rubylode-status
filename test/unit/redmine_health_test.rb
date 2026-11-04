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

class RubylodeStatus::RedmineHealthTest < ActiveSupport::TestCase
  test "Redmine's version and a reachable database" do
    assert_equal({ version: Redmine::VERSION.to_s, database: "ok" }, RubylodeStatus::RedmineHealth.new.to_h)
  end

  test "a database that does not answer is down" do
    failing_connection = Object.new
    def failing_connection.select_value(*)
      raise ActiveRecord::ConnectionNotEstablished, "could not connect"
    end

    health = RubylodeStatus::RedmineHealth.new(connection: -> { failing_connection })

    assert_equal "down", health.to_h[:database]
  end
end
