# aigifmaker

Turn text into animated GIFs with AI GIF Maker. Native GIF generation — no video conversion. Type what you want and download your GIF in about a minute.

This is the official Ruby client for [AI GIF Maker](https://aigifmaker.ai/?utm_source=rubygems&utm_medium=package). One call sends your prompt, waits for the GIF and returns its URL.

```bash
gem install aigifmaker
```

```ruby
require "aigifmaker"

url = Aigifmaker.generate("a corgi in sunglasses dancing on a beach, looping")
puts url # the finished GIF
```

Standard library only (`net/http`, `json`), no dependencies. Ruby 2.6+.

## API key

Create a key at https://aigifmaker.ai/settings/apikeys, then pass it as `api_key:` or export it:

```bash
export AIGIFMAKER_API_KEY=sk-...
```

Each GIF costs 1 credit on your AI GIF Maker account, the same as on the website. New accounts get one free GIF (it carries a small aigifmaker.ai badge). A GIF that fails to generate gives its credit back. Credit packs are on the [pricing](https://aigifmaker.ai/pricing?utm_source=rubygems&utm_medium=package) page.

```ruby
puts Aigifmaker.credits # remaining credits, free to call
```

## Client

```ruby
gif = Aigifmaker::Client.new("sk-...", timeout: 300) # timeout in seconds, 5 minutes by default
url = gif.generate("a tiny dragon sneezing a puff of glitter")
```

## Submit now, collect later

```ruby
task_id = gif.submit("happy birthday text bouncing in rainbow letters")
puts gif.status(task_id)["status"] # pending | processing | success | failed
url = gif.wait(task_id)            # polls every 3 seconds
```

A run from an account that has not bought credits yet may wait in a short queue first (`"queued" => true` while `status` stays `processing`). That is normal; `generate` and `wait` keep polling.

## Errors worth catching

Each failure is its own subclass of `Aigifmaker::Error`:

- `Aigifmaker::AuthError`: no key, or the key is wrong or deleted
- `Aigifmaker::QuotaError`: the account is out of credits
- `Aigifmaker::RejectedError`: the content filter refused the prompt, or a cooldown is active; reword it
- `Aigifmaker::GenerationFailed`: the run was accepted but failed; the message says why
- `Aigifmaker::TimeoutError`: still running when the timeout passed; the GIF may finish later in your history

Any other refusal raises `Aigifmaker::Error` with the server's message.

## Tests

```bash
ruby test/test_aigifmaker.rb # mocked, offline
ruby test/smoke_live.rb      # two free live checks, no generation
```

MIT licensed. Questions: support@aigifmaker.ai
