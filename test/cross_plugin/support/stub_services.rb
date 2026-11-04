require "socket"
require "json"
require "uri"
require "time"

# Tiny HTTP servers that answer the way Beszel, GlitchTip, Uptime Kuma and Windmill do, for the requests the four plugins
# make. Standard library only, on a loopback port picked by the system. Each stub keeps its answer in an attribute, so a
# test changes what the "service" says between two page loads.
module CrossPluginStubs
  # One loopback HTTP server. The block gets the method, the path, the query as a hash and the headers, and returns
  # [status, content_type, body, extra_headers].
  class Server
    attr_reader :port, :requests

    def initialize(&handler)
      @handler = handler
      @requests = []
      @listener = TCPServer.new("127.0.0.1", 0)
      @port = @listener.addr[1]
      @thread = Thread.new { serve }
    end

    def base_url
      "http://127.0.0.1:#{port}"
    end

    def stop
      @thread.kill
      @listener.close
    rescue IOError
      nil
    end

    private

    def serve
      loop do
        client = @listener.accept
        Thread.new(client) { |connection| answer(connection) }
      end
    end

    def answer(connection)
      request_line = connection.gets.to_s
      method, target, = request_line.split(" ")
      headers = {}
      while (line = connection.gets) && line.strip != ""
        name, value = line.split(":", 2)
        headers[name.strip.downcase] = value.to_s.strip
      end
      length = headers["content-length"].to_i
      body = length.positive? ? connection.read(length) : ""
      uri = URI.parse(target.to_s)
      query = URI.decode_www_form(uri.query.to_s).to_h
      @requests << { method: method, path: uri.path, query: query, headers: headers, body: body }
      status, content_type, payload, extra = @handler.call(method, uri.path, query, headers)
      head = ["HTTP/1.1 #{status} OK", "Content-Type: #{content_type}", "Content-Length: #{payload.bytesize}", "Connection: close"]
      (extra || {}).each { |name, value| head << "#{name}: #{value}" }
      connection.write(head.join("\r\n") + "\r\n\r\n" + payload)
    rescue StandardError
      nil
    ensure
      connection.close
    end
  end

  class Beszel
    attr_accessor :systems, :sign_in_status

    def initialize
      @sign_in_status = 200
      @systems = []
      @server = Server.new { |method, path, _query, _headers| respond(method, path) }
    end

    def base_url = @server.base_url
    def stop = @server.stop

    def system(name, status: "up", cpu: 10, memory: 30, disk: 40)
      { "name" => name, "status" => status, "updated" => Time.now.utc.iso8601,
        "info" => { "cpu" => cpu, "mp" => memory, "dp" => disk } }
    end

    private

    def respond(method, path)
      if method == "POST" && path.end_with?("/auth-with-password")
        return [@sign_in_status, "application/json", JSON.generate("token" => "stub-session")]
      end

      [200, "application/json", JSON.generate("items" => @systems)]
    end
  end

  class Glitchtip
    attr_accessor :issues

    def initialize
      @issues = []
      @server = Server.new { |_method, _path, _query, _headers| [200, "application/json", JSON.generate(@issues)] }
    end

    def base_url = @server.base_url
    def stop = @server.stop

    def issue(id, title, level: "error", count: 5, project: "web")
      now = Time.now.utc.iso8601
      { "id" => id.to_s, "shortId" => "WEB-#{id}", "title" => title, "culprit" => "app", "level" => level, "count" => count.to_s,
        "firstSeen" => now, "lastSeen" => now, "status" => "unresolved", "project" => { "slug" => project, "name" => project } }
    end
  end

  class UptimeKuma
    attr_accessor :monitors, :metrics_status

    def initialize
      @monitors = {}
      @metrics_status = 200
      @server = Server.new { |_method, path, _query, _headers| path == "/metrics" ? [@metrics_status, "text/plain", metrics] : [404, "text/plain", ""] }
    end

    def base_url = @server.base_url
    def stop = @server.stop
    def requests = @server.requests

    private

    def metrics
      @monitors.flat_map do |name, (up, milliseconds)|
        labels = %(monitor_name="#{name}",monitor_type="http",monitor_url="https://example.test",monitor_hostname="null",monitor_port="null")
        ["monitor_status{#{labels}} #{up ? 1 : 0}", "monitor_response_time{#{labels}} #{milliseconds}"]
      end.join("\n") + "\n"
    end
  end

  class Windmill
    attr_accessor :failed_jobs, :schedules, :latest_runs

    def initialize
      @failed_jobs = []
      @schedules = {}
      @latest_runs = {}
      @server = Server.new { |_method, path, query, _headers| respond(path, query) }
    end

    def base_url = @server.base_url
    def stop = @server.stop

    def failed_job(id, script_path, error: "Boom")
      now = Time.now.utc.iso8601(3)
      { "id" => id, "script_path" => script_path, "job_kind" => "script", "success" => false, "started_at" => now,
        "created_at" => now, "completed_at" => now, "result" => { "error" => { "name" => "Error", "message" => error } } }
    end

    private

    def respond(path, query)
      json = "application/json"
      case path
      when %r{/jobs/completed/list\z}
        if query["schedule_path"]
          [200, json, JSON.generate([@latest_runs[query["schedule_path"]]].compact)]
        elsif query["success"] == "false"
          [200, json, JSON.generate(@failed_jobs)]
        else
          [200, json, "[]"]
        end
      when %r{/schedules/get/(.+)\z}
        schedule = @schedules[Regexp.last_match(1)]
        schedule ? [200, json, JSON.generate(schedule)] : [404, json, "{}"]
      else
        [404, json, "{}"]
      end
    end
  end

  def self.start_all
    { beszel: Beszel.new, glitchtip: Glitchtip.new, uptime_kuma: UptimeKuma.new, windmill: Windmill.new }
  end
end
