# Free live smoke tests against https://aigifmaker.ai. No generation runs.
#
#   ruby test/smoke_live.rb
require "minitest/autorun"
require_relative "../lib/aigifmaker"

class AigifmakerLiveSmoke < Minitest::Test
  def setup
    ENV.delete("AIGIFMAKER_API_KEY")
  end

  def test_invalid_key_is_auth_error
    assert_raises(Aigifmaker::AuthError) { Aigifmaker.credits(api_key: "sk-invalidtest000") }
  end

  def test_no_key_hits_wall
    assert_raises(Aigifmaker::AuthError) { Aigifmaker.submit("smoke test: a blinking star") }
  end
end
