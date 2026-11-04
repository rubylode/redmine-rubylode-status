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
  # Who is looking at the page: a Redmine user, or a monitor holding the status token.
  class Viewer
    def self.for_user(user)
      new(signed_in: user.logged?, administrator: user.admin?)
    end

    # The token is read only and stands for "someone signed in", never for an administrator.
    def self.token_holder
      new(signed_in: true, administrator: false)
    end

    def initialize(signed_in:, administrator:)
      @signed_in = signed_in
      @administrator = administrator
    end

    def may_see?(widget)
      case widget.visibility
      when "logged_in" then @signed_in
      when "admins" then @administrator
      else false
      end
    end
  end
end
