# Serves Redmine on port 3000 with all five plugins, the stub services running in this process and the four widgets set up
# against them, so /status shows ok, warning and down blocks. Used by `bin/test-with-widgets preview`. Test database, admin/admin.
ENV["RAILS_ENV"] = "test"
require "/usr/src/redmine/config/environment"
require "rackup"
require_relative "stub_services"

stubs = CrossPluginStubs.start_all
beszel = stubs[:beszel]
beszel.systems = [beszel.system("web-1", cpu: 22, memory: 41), beszel.system("db-1", cpu: 94, memory: 60), beszel.system("backup-1", status: "down")]
glitchtip = stubs[:glitchtip]
glitchtip.issues = [glitchtip.issue(1, "NoMethodError in OrdersController#create", count: 41),
                    glitchtip.issue(2, "Timeout talking to the payment provider", level: "fatal", count: 3)]
stubs[:uptime_kuma].monitors = { "Website" => [true, 112], "Mail" => [true, 64], "Wiki" => [true, 240] }
windmill = stubs[:windmill]
windmill.failed_jobs = [windmill.failed_job("job-1", "f/billing/nightly_invoices", error: "connection refused")]

ENV["BESZEL_EMAIL"] = "preview@example.test"
ENV["BESZEL_PASSWORD"] = "preview-password"
ENV["GLITCHTIP_API_TOKEN"] = "preview-glitchtip"
ENV["UPTIME_KUMA_API_TOKEN"] = "preview-kuma"
ENV["WINDMILL_API_TOKEN"] = "preview-windmill"

settings = {
  "beszel" => { "base_url" => beszel.base_url, "systems" => "" },
  "glitchtip" => { "base_url" => glitchtip.base_url, "organization_slug" => "acme" },
  "uptime_kuma" => { "base_url" => stubs[:uptime_kuma].base_url,
                     "services" => "Website | https://example.test | Front page | Website\nMail | https://example.test | Mail | Mail\nWiki | https://example.test | Wiki | Wiki" },
  "windmill" => { "base_url" => windmill.base_url, "workspace_id" => "main" }
}
settings.each do |key, values|
  defaults = "Rubylode#{key.split('_').map(&:capitalize).join}::Settings".sub("Glitchtip", "Glitchtip").constantize::DEFAULTS
  Setting.send(:"plugin_redmine_rubylode_#{key}=", defaults.to_h { |name, value| [name, value.dup] }.merge(values))
end
User.find_by(login: "admin").update_columns(must_change_passwd: false)

puts "PREVIEW READY"
$stdout.flush
Rackup::Server.start(app: Rails.application, Host: "0.0.0.0", Port: 3000, environment: "test")
