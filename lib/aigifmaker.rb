# Official Ruby SDK for AI GIF Maker (https://aigifmaker.ai): turn text into
# animated GIFs.
#
#   require "aigifmaker"
#   url = Aigifmaker.generate("a corgi in sunglasses dancing on a beach")
#
# Create a key at https://aigifmaker.ai/settings/apikeys and pass it as
# api_key: or set AIGIFMAKER_API_KEY. Each GIF costs 1 credit on your
# AI GIF Maker account, the same as on the website.
require "json"
require "net/http"
require "uri"
require_relative "aigifmaker/version"

module Aigifmaker
  BASE_URL = "https://aigifmaker.ai".freeze
  KEYS_URL = "https://aigifmaker.ai/settings/apikeys".freeze
  PRICING_URL = "https://aigifmaker.ai/pricing".freeze
  DEFAULT_TIMEOUT = 900
  POLL_EVERY = 3

  # Base of every error this gem raises. #code is the JSON code when there was one.
  class Error < StandardError
    attr_reader :code
    def initialize(msg = nil, code: nil)
      super(msg)
      @code = code
    end
  end
  # No API key, or the key is invalid or deleted.
  class AuthError < Error; end
  # The account is out of credits.
  class QuotaError < Error; end
  # The content filter refused the prompt, or a cooldown is active. Reword it.
  class RejectedError < Error; end
  # The GIF was accepted but the run ended as failed or canceled.
  class GenerationFailed < Error; end
  # The deadline passed; the GIF may still finish in your AI GIF Maker history.
  class TimeoutError < Error; end

  # Return data for code 0; otherwise raise the error that says what to do next.
  # Every response is HTTP 200; the JSON code tells success from refusal.
  def self.unwrap(http_status, env)
    env = {} unless env.is_a?(Hash)
    code = env["code"]
    data = env["data"].is_a?(Hash) ? env["data"] : {}
    if code == 0
      raise AuthError.new("an API key is required; create one at #{KEYS_URL} and set AIGIFMAKER_API_KEY", code: code) if data["wall"]

      return data
    end
    msg = (env["message"] || env["error"] || "HTTP #{http_status}").to_s
    low = msg.downcase
    c = code.is_a?(Integer) ? code : nil
    raise AuthError.new(msg, code: c) if low.include?("invalid api key") || low.include?("no auth") || http_status == 401
    raise QuotaError.new("#{msg}. Top up at #{PRICING_URL}", code: c) if low.include?("insufficient credits")
    raise RejectedError.new(msg, code: c) if c && c != -1

    raise Error.new(msg, code: c)
  end

  # A client bound to one API key. transport: is a callable (url, body, headers) -> [status, hash], for tests.
  class Client
    attr_accessor :poll_every, :timeout

    def initialize(api_key = nil, base_url: BASE_URL, timeout: DEFAULT_TIMEOUT, poll_every: POLL_EVERY, transport: nil)
      key = (api_key || ENV["AIGIFMAKER_API_KEY"]).to_s.strip
      @key = key.empty? ? nil : key
      @base = base_url.chomp("/")
      @timeout = timeout
      @poll_every = poll_every
      @transport = transport || method(:http)
    end

    # Start one GIF and return its task id without waiting.
    def submit(prompt)
      raise ArgumentError, "prompt is required" if prompt.to_s.strip.empty?

      data = post("/api/ai/generate", {
        "provider" => "openlux",
        "mediaType" => "image",
        "model" => "gif-maker-v1",
        "scene" => "text-to-image",
        "prompt" => prompt,
        "options" => { "output_format" => "gif" }
      })
      raise Error, "the service returned no task id" unless data["id"]

      data["id"].to_s
    end

    # Return the task record: "status" is pending, processing, success or failed;
    # "images"[0] holds the GIF URL when it succeeds.
    def status(task_id)
      post("/api/ai/query", { "taskId" => task_id })
    end

    # Poll a task every 3 seconds until it finishes and return the GIF URL.
    def wait(task_id, timeout: nil)
      limit = timeout || @timeout
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + limit
      loop do
        d = begin
          status(task_id)
        rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout
          {} # a dropped poll is not a failed generation
        end
        state = d["status"].to_s.downcase
        images = d["images"] || []
        return images[0].to_s if state == "success" && !images.empty?

        if %w[failed canceled].include?(state)
          msg = (d["errorMessage"] || "the GIF #{state}").to_s
          raise RejectedError, msg if d["failureKind"] == "moderation"

          raise GenerationFailed, msg
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise TimeoutError, "still running after #{limit}s; task #{task_id} may finish later in your AI GIF Maker history"
        end

        sleep @poll_every
      end
    end

    # Generate one animated GIF and return its URL.
    def generate(prompt)
      wait(submit(prompt))
    end

    # Remaining credits on the account. Free to call.
    def credits
      post("/api/user/get-user-credits", nil)["remainingCredits"].to_i
    end

    private

    def post(path, body)
      headers = { "Content-Type" => "application/json", "User-Agent" => "aigifmaker-ruby/#{VERSION}" }
      headers["Authorization"] = "Bearer #{@key}" if @key
      st, env = @transport.call("#{@base}#{path}", body, headers)
      Aigifmaker.unwrap(st, env)
    end

    def http(url, body, headers)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      headers.each { |k, v| req[k] = v }
      req.body = JSON.generate(body || {})
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 60) { |h| h.request(req) }
      parsed = begin
        JSON.parse(res.body.to_s.empty? ? "{}" : res.body)
      rescue JSON::ParserError
        { "code" => -1, "message" => res.body.to_s[0, 200] }
      end
      [res.code.to_i, parsed.is_a?(Hash) ? parsed : { "code" => -1, "message" => parsed.to_s }]
    end
  end

  # Generate one animated GIF and return its URL.
  def self.generate(prompt, api_key: nil, **opts)
    Client.new(api_key, **opts).generate(prompt)
  end

  # Start one GIF and return its task id.
  def self.submit(prompt, api_key: nil, **opts)
    Client.new(api_key, **opts).submit(prompt)
  end

  # Return the task record for task_id.
  def self.status(task_id, api_key: nil, **opts)
    Client.new(api_key, **opts).status(task_id)
  end

  # Remaining credits on the account.
  def self.credits(api_key: nil, **opts)
    Client.new(api_key, **opts).credits
  end
end
