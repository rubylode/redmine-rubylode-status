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

class RubylodeStatus::StatusTokenTest < ActiveSupport::TestCase
  def request_with(headers)
    ActionDispatch::TestRequest.create(headers.transform_keys { |name| "HTTP_#{name.upcase.tr('-', '_')}" })
  end

  test "the token is accepted as a bearer token or in X-Status-Token" do
    token = RubylodeStatus::StatusToken.new("status-token-for-tests")

    assert token.accepts?(request_with("Authorization" => "Bearer status-token-for-tests"))
    assert token.accepts?(request_with("X-Status-Token" => "status-token-for-tests"))
  end

  test "a wrong, empty or missing token is refused" do
    token = RubylodeStatus::StatusToken.new("status-token-for-tests")

    refute token.accepts?(request_with("Authorization" => "Bearer status-token-for-test"))
    refute token.accepts?(request_with("X-Status-Token" => ""))
    refute token.accepts?(request_with("Authorization" => "Basic c3RhdHVzOnRva2Vu"))
    refute token.accepts?(request_with({}))
  end

  test "nothing is accepted when no token is configured" do
    token = RubylodeStatus::StatusToken.new(nil)

    refute token.configured?
    refute token.accepts?(request_with("X-Status-Token" => ""))
    refute token.accepts?(request_with("Authorization" => "Bearer "))
  end

  test "inspecting the object does not show the token" do
    refute_includes RubylodeStatus::StatusToken.new("status-token-for-tests").inspect, "status-token-for-tests"
  end
end
