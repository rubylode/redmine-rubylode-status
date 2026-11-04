# Shared setup for the tests that run all five Rubylode status plugins in one Redmine. See bin/test-with-widgets.
require File.expand_path("test/test_helper", ENV.fetch("REDMINE_ROOT", "/usr/src/redmine"))
require_relative "stub_services"

module CrossPluginTestHelpers
  WIDGET_KEYS = %w[beszel glitchtip uptime_kuma windmill].freeze
  DEFAULT_TITLES = { "beszel" => "Servers", "glitchtip" => "Errors", "uptime_kuma" => "Services", "windmill" => "Windmill" }.freeze
  OLD_MENU_CAPTIONS = ["Servers", "Errors", "Service status", "Windmill status"].freeze
  OLD_PATHS = { "/beszel_status" => "beszel", "/glitchtip_errors" => "glitchtip", "/service_status" => "uptime_kuma",
                "/windmill_status" => "windmill" }.freeze
  SETTING_CLASSES = {
    "beszel" => "RubylodeBeszel::Settings", "glitchtip" => "RubylodeGlitchtip::Settings",
    "uptime_kuma" => "RubylodeUptimeKuma::Settings", "windmill" => "RubylodeWindmill::Settings"
  }.freeze
  NOTICE_MISSING = "Install Rubylode Status to see this with the other status blocks on one page."
  BASE_MENU = ["Home", "My page", "Projects", "Administration", "Help"].freeze

  def plugin_id(key) = "redmine_rubylode_#{key}"

  def default_settings(key)
    SETTING_CLASSES.fetch(key).constantize::DEFAULTS.to_h { |name, value| [name, value.dup] }
  end

  def save_settings(key, overrides = {})
    Setting.send(:"plugin_#{plugin_id(key)}=", default_settings(key).merge(overrides.transform_keys(&:to_s)))
  end

  def save_status_settings(overrides = {})
    Setting.send(:plugin_redmine_rubylode_status=, RubylodeStatus::Settings::DEFAULTS.merge(overrides.transform_keys(&:to_s)))
  end

  # Settings that point every widget at the stub services, with the credential variables set.
  def point_widgets_at(stubs, overrides = {})
    ENV["BESZEL_EMAIL"] = "stub@example.test"
    ENV["BESZEL_PASSWORD"] = "stub-password"
    ENV["GLITCHTIP_API_TOKEN"] = "stub-glitchtip-token"
    ENV["UPTIME_KUMA_API_TOKEN"] = "stub-kuma-token"
    ENV["WINDMILL_API_TOKEN"] = "stub-windmill-token"
    Rails.cache.clear
    save_settings("beszel", { "base_url" => stubs[:beszel].base_url, "cache_seconds" => "0", "failure_cache_seconds" => "0" }.merge(overrides.fetch("beszel", {})))
    save_settings("glitchtip", { "base_url" => stubs[:glitchtip].base_url, "organization_slug" => "acme", "cache_seconds" => "0",
                                 "failure_cache_seconds" => "0" }.merge(overrides.fetch("glitchtip", {})))
    save_settings("uptime_kuma", { "base_url" => stubs[:uptime_kuma].base_url, "cache_seconds" => "0", "failure_cache_seconds" => "0",
                                   "services" => "Website | https://example.test | Front page | Website\nMail | https://example.test | Mail | Mail" }.merge(overrides.fetch("uptime_kuma", {})))
    save_settings("windmill", { "base_url" => stubs[:windmill].base_url, "workspace_id" => "main", "cache_seconds" => "0",
                                "failure_cache_seconds" => "0" }.merge(overrides.fetch("windmill", {})))
  end

  def top_menu_captions
    css_select("#main-menu, #top-menu").flat_map { |menu| menu.css("a") }.map { |link| link.text.strip }.reject(&:empty?)
  end

  def main_top_menu_captions
    document = Nokogiri::HTML(response.body)
    document.css("#top-menu #main-menu a, #top-menu > ul a").map { |link| link.text.strip }.reject(&:empty?)
  end

  def page_document
    Nokogiri::HTML(response.body)
  end

  def status_widget_keys_on_page
    page_document.css("div.rubylode-status-widget").map { |node| node["id"].delete_prefix("rubylode-status-widget-") }
  end

  def with_status? = ENV["CROSS_PLUGIN_WITH_STATUS"] == "1"
end
