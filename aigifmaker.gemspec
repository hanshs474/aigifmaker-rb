require_relative "lib/aigifmaker/version"

Gem::Specification.new do |s|
  s.name        = "aigifmaker"
  s.version     = Aigifmaker::VERSION
  s.summary     = "Official SDK for AI GIF Maker (aigifmaker.ai): turn text into animated GIFs."
  s.description = "Turn text into animated GIFs with AI GIF Maker. Native GIF generation — no video conversion. Type what you want and download your GIF in about a minute."
  s.authors     = ["hanshs474"]
  s.email       = ["support@aigifmaker.ai"]
  s.homepage    = "https://aigifmaker.ai/?utm_source=rubygems&utm_medium=package"
  s.license     = "MIT"
  s.files       = Dir["lib/**/*.rb"] + ["README.md", "LICENSE"]
  s.required_ruby_version = ">= 2.6"
  s.metadata    = {
    "homepage_uri"      => "https://aigifmaker.ai/?utm_source=rubygems&utm_medium=package",
    "source_code_uri"   => "https://github.com/hanshs474/aigifmaker-rb",
    "bug_tracker_uri"   => "https://github.com/hanshs474/aigifmaker-rb/issues",
    "rubygems_mfa_required" => "false"
  }
end
