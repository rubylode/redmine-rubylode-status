# Boots Redmine the way the demo setups do (production mode, rails server) with whatever plugins are mounted, waits for
# /login, signs in and opens the front page, and prints the Redmine log when anything fails. Run inside the test container
# by `bin/test-with-widgets nine-plugins`; not a Minitest file.
require "net/http"
require "timeout"

READY_SECONDS = Integer(ENV.fetch("READY_SECONDS", "240"))
log_path = "/usr/src/redmine/log/production.log"
server_log = "/tmp/server.log"
started = Time.now
pid = Process.spawn({ "RAILS_ENV" => "production" }, "bundle", "exec", "rails", "server", "-b", "127.0.0.1", "-p", "3000", "-e", "production",
                    chdir: "/usr/src/redmine", out: server_log, err: [:child, :out])

def get(path)
  Net::HTTP.get_response(URI("http://127.0.0.1:3000#{path}"))
end

ready = false
until ready || Time.now - started > READY_SECONDS || Process.waitpid(pid, Process::WNOHANG)
  begin
    ready = get("/login").code == "200"
  rescue SystemCallError, EOFError, Net::ReadTimeout
    sleep 2
  end
end

if ready
  puts "READY after #{(Time.now - started).round} seconds"
else
  puts "NOT READY after #{(Time.now - started).round} seconds (the server process #{Process.waitpid(pid, Process::WNOHANG).nil? ? "was still running" : "exited"})"
end
%w[/login /projects].each do |path|
  begin
    puts "GET #{path} -> #{get(path).code}"
  rescue StandardError => error
    puts "GET #{path} -> #{error.class}"
  end
end
unless ready
  puts "--- server output"
  puts File.read(server_log).lines.last(60).join
  puts "--- production.log"
  puts File.exist?(log_path) ? File.read(log_path).lines.last(60).join : "(none)"
end
begin
  Process.kill("TERM", pid)
rescue Errno::ESRCH
  nil
end
exit(ready ? 0 : 1)
