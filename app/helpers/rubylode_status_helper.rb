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

module RubylodeStatusHelper
  def rubylode_status_state_label(state)
    l("rubylode_status.states.#{state}")
  end

  # The body of a block: the plugin's own partial when it gave one, the list of items otherwise. A partial that
  # fails is replaced by a short message, so the rest of the page still draws.
  def rubylode_status_widget_body(widget, status)
    if widget.partial && !status.failed?
      render(partial: widget.partial, locals: { widget: widget, status: status })
    else
      render(partial: "rubylode_status/items", locals: { status: status })
    end
  rescue StandardError => error
    Rails.logger.error("Rubylode Status: the #{widget.key} partial #{widget.partial} failed: #{error.class}: #{error.message}")
    content_tag(:p, l("rubylode_status.widget.drawing_failed"), class: "rubylode-status-drawing-failed")
  end
end
