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

require "openssl"
require "digest"

module RubylodeStatus
  # The optional read-only token for /status.json. It comes in an "Authorization: Bearer" or an "X-Status-Token"
  # header, never in the address (addresses end up in logs). Both sides are hashed first, so the comparison takes
  # the same time whatever the length or content of the guess.
  class StatusToken
    BEARER_PATTERN = /\ABearer\s+(.+)\z/i

    def self.configured(settings = Settings.current)
      new(settings.token)
    end

    def self.presented_in(request)
      header = request.headers["X-Status-Token"].to_s.strip
      return header unless header.empty?

      request.authorization.to_s.strip[BEARER_PATTERN, 1].to_s.strip
    end

    def initialize(expected)
      @expected = expected.to_s
    end

    def configured?
      !@expected.empty?
    end

    def accepts?(request)
      presented = self.class.presented_in(request)
      return false if !configured? || presented.empty?

      OpenSSL.fixed_length_secure_compare(Digest::SHA256.digest(presented), Digest::SHA256.digest(@expected))
    end

    def inspect
      "#<#{self.class.name} configured=#{configured?}>"
    end
  end
end
