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
  # The widgets one viewer gets, in the order and columns the settings give. Asking which widgets there are does not
  # call any of them; only statuses does, once per page.
  class Page
    def initialize(viewer:, settings: Settings.current, registry: Registry)
      @viewer = viewer
      @settings = settings
      @registry = registry
    end

    attr_reader :settings

    # Every registered widget in page order, whoever may see it: the list on the settings page.
    def ordered_widgets
      @registry.widgets.each_with_index
               .sort_by { |widget, index| sort_key(widget, index) }
               .map(&:first)
    end

    def widgets
      @widgets ||= ordered_widgets.select { |widget| @settings.layout_for(widget.key).shown? && @viewer.may_see?(widget) }
    end

    def any?
      widgets.any?
    end

    def registered?
      @registry.any?
    end

    def left_widgets
      widgets.reject { |widget| right?(widget) }
    end

    def right_widgets
      widgets.select { |widget| right?(widget) }
    end

    def two_columns?
      right_widgets.any? && left_widgets.any?
    end

    def statuses
      @statuses ||= widgets.to_h do |widget|
        [widget.key, WidgetStatus.fetch(widget, timeout_seconds: @settings.timeout_seconds)]
      end
    end

    def status_for(widget)
      statuses.fetch(widget.key)
    end

    private

    def right?(widget)
      @settings.layout_for(widget.key).column == "right"
    end

    def sort_key(widget, index)
      position = @settings.layout_for(widget.key).position
      position ? [0, position, index] : [1, 0, index]
    end
  end
end
