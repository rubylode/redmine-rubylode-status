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

require "timeout"

module RubylodeStatus
  # What one widget reported, reduced to the contract: a state, a one-line summary and a list of items. A widget that
  # raises, takes too long or returns something else becomes "unknown" with a short message, so one broken plugin
  # never takes the page down. The error itself goes to the log, not to the page: it may name hosts or addresses.
  class WidgetStatus
    STATES = %w[ok warning down unknown].freeze
    UNKNOWN = "unknown".freeze

    # Raised by the page's time limit only, so a plugin's own network timeout counts as a failure, not as this.
    class TookTooLong < StandardError; end

    attr_reader :widget, :state, :summary, :items, :data

    def self.fetch(widget, timeout_seconds:, logger: Rails.logger)
      data = Timeout.timeout(timeout_seconds, TookTooLong) { widget.data.call }
      return failure(widget, I18n.t("rubylode_status.widget.no_data")) unless data.is_a?(Hash)

      new(widget, data)
    rescue TookTooLong
      logger&.warn("Rubylode Status: the #{widget.key} block did not answer within #{timeout_seconds} seconds")
      failure(widget, I18n.t("rubylode_status.widget.timed_out", seconds: timeout_seconds))
    rescue StandardError => error
      logger&.error("Rubylode Status: the #{widget.key} block failed: #{error.class}: #{error.message}\n" \
                    "#{Array(error.backtrace).first(10).join("\n")}")
      failure(widget, I18n.t("rubylode_status.widget.failed"))
    end

    def self.failure(widget, message)
      new(widget, { state: UNKNOWN, summary: message }, failed: true)
    end

    def initialize(widget, data, failed: false)
      @widget = widget
      @data = data.to_h.symbolize_keys
      @failed = failed
      @state = state_from(@data[:state])
      @summary = @data[:summary].to_s.squish
      @items = Array(@data[:items]).filter_map { |item| item_from(item) }
    end

    def failed?
      @failed
    end

    def to_h
      { key: widget.key, title: widget.title, state: state, summary: summary, items: items, path: widget.path }
    end

    private

    def state_from(value)
      state = value.to_s
      STATES.include?(state) ? state : UNKNOWN
    end

    def item_from(item)
      return nil unless item.respond_to?(:to_h)

      item = item.to_h.symbolize_keys
      { name: item[:name].to_s, state: state_from(item[:state]), detail: item[:detail]&.to_s }
    end
  end
end
