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

class RubylodeStatusController < ApplicationController
  accept_api_auth :index
  before_action :require_status_access

  helper RubylodeStatusHelper

  def index
    @page = RubylodeStatus::Page.new(viewer: viewer)

    if json_request?
      render json: status_document
    elsif @page.registered? && !@page.any?
      render_403
    end
  end

  private

  # Redmine treats a .json request as an API call and ignores the browser session for it. Here a signed-in browser may
  # read /status.json too, so the request is handled as an ordinary one: session first, then an API key (Redmine's own
  # lookup, with the REST API turned on). The action only reads.
  def api_request?
    false
  end

  # The action checks access itself, so a monitor with the token gets through when Redmine requires a login.
  def check_if_login_required
    true
  end

  def require_status_access
    return true if User.current.logged? || status_token_accepted?

    if json_request?
      render json: { error: l("rubylode_status.api.unauthorized") }, status: :unauthorized
    else
      require_login
    end
    false
  end

  def status_token_accepted?
    return @status_token_accepted if defined?(@status_token_accepted)

    @status_token_accepted = json_request? && RubylodeStatus::StatusToken.configured.accepts?(request)
  end

  def viewer
    if User.current.logged?
      RubylodeStatus::Viewer.for_user(User.current)
    else
      RubylodeStatus::Viewer.token_holder
    end
  end

  def json_request?
    params[:format] == "json"
  end

  def status_document
    {
      redmine: RubylodeStatus::RedmineHealth.new.to_h,
      generated_at: Time.current.utc.iso8601,
      widgets: @page.widgets.map { |widget| @page.status_for(widget).to_h }
    }
  end
end
