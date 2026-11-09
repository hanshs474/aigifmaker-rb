require "minitest/autorun"
require_relative "../lib/aigifmaker"

# Mocked unit tests in the real response shapes (every response is HTTP 200; JSON code decides).
class AigifmakerTest < Minitest::Test
  GIF = "https://cdn.aigifmaker.ai/out/a.gif".freeze

  def ok(data)
    [200, { "code" => 0, "message" => "ok", "data" => data }]
  end

  def err(msg, code = -1)
    [200, { "code" => code, "message" => msg }]
  end

  # submit -> polls (each element of `polls` is one query reply)
  def fake(calls, polls)
    i = 0
    lambda do |url, body, headers|
      calls << [url, body, headers]
      if url.end_with?("/api/ai/generate")
        ok({ "id" => "t1", "status" => "pending", "taskId" => "up-1" })
      elsif url.end_with?("/api/user/get-user-credits")
        ok({ "remainingCredits" => 7, "made" => 2 })
      else
        r = polls[[i, polls.size - 1].min]
        i += 1
        r
      end
    end
  end

  def client(transport, key = "sk-test")
    Aigifmaker::Client.new(key, poll_every: 0, transport: transport)
  end

  def test_success_flow_and_request_body
    calls = []
    c = client(fake(calls, [ok({ "id" => "t1", "status" => "processing" }), ok({ "id" => "t1", "status" => "success", "images" => [GIF], "watermarked" => [false] })]))
    assert_equal GIF, c.generate("a dancing cat")
    assert_equal "https://aigifmaker.ai/api/ai/generate", calls[0][0]
    assert_equal({ "provider" => "openlux", "mediaType" => "image", "model" => "gif-maker-v1", "scene" => "text-to-image",
                   "prompt" => "a dancing cat", "options" => { "output_format" => "gif" } }, calls[0][1])
    assert_equal "Bearer sk-test", calls[0][2]["Authorization"]
    assert_equal({ "taskId" => "t1" }, calls[1][1])
    assert_equal 7, c.credits
  end

  def test_queued_keeps_polling
    calls = []
    queued = ok({ "id" => "t1", "status" => "processing", "queued" => true, "queueEta" => 30 })
    c = client(fake(calls, [queued, queued, ok({ "id" => "t1", "status" => "success", "images" => [GIF], "watermarked" => [true] })]))
    assert_equal GIF, c.generate("x")
    assert_equal 4, calls.size
  end

  def test_failed_run
    c = client(fake([], [ok({ "id" => "t1", "status" => "failed", "errorMessage" => "upstream error" })]))
    e = assert_raises(Aigifmaker::GenerationFailed) { c.generate("x") }
    assert_equal "upstream error", e.message
  end

  def test_moderation_failure_is_rejected
    c = client(fake([], [ok({ "id" => "t1", "status" => "failed", "errorMessage" => "blocked", "failureKind" => "moderation" })]))
    assert_raises(Aigifmaker::RejectedError) { c.generate("x") }
  end

  def test_invalid_key
    c = client(->(_u, _b, _h) { err("invalid API key — create one at https://aigifmaker.ai/settings/apikeys") })
    assert_raises(Aigifmaker::AuthError) { c.credits }
  end

  def test_wall_without_key
    old = ENV.delete("AIGIFMAKER_API_KEY")
    seen = nil
    c = Aigifmaker::Client.new(nil, transport: lambda { |_u, _b, h|
      seen = h
      ok({ "wall" => true, "reason" => "anon_credits" })
    })
    e = assert_raises(Aigifmaker::AuthError) { c.submit("x") }
    assert_includes e.message, "settings/apikeys"
    refute seen.key?("Authorization")
  ensure
    ENV["AIGIFMAKER_API_KEY"] = old if old
  end

  def test_insufficient_credits
    c = client(->(_u, _b, _h) { err("insufficient credits") })
    e = assert_raises(Aigifmaker::QuotaError) { c.submit("x") }
    assert_includes e.message, "aigifmaker.ai/pricing"
  end

  def test_cooldown_and_generic
    assert_raises(Aigifmaker::RejectedError) { client(->(_u, _b, _h) { err("slow down", 429) }).submit("x") }
    e = assert_raises(Aigifmaker::Error) { client(->(_u, _b, _h) { err("something else") }).submit("x") }
    assert_instance_of Aigifmaker::Error, e
  end

  def test_timeout
    c = Aigifmaker::Client.new("sk", poll_every: 0, timeout: 0, transport: fake([], [ok({ "id" => "t1", "status" => "processing" })]))
    assert_raises(Aigifmaker::TimeoutError) { c.generate("x") }
  end

  def test_empty_prompt
    assert_raises(ArgumentError) { client(fake([], [])).submit("  ") }
  end
end
