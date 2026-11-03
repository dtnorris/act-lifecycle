# frozen_string_literal: true

# Read metadata without executing production before test coverage starts.
version_source = File.read(File.join(__dir__, "lib/act_lifecycle/version.rb"))

Gem::Specification.new do |specification|
  specification.name = "act-lifecycle"
  specification.version = version_source[/VERSION = "([^"]+)"/, 1]
  specification.summary = "Independent ACT lifecycle package foundation"
  specification.authors = ["David Norris"]
  specification.license = "MIT"
  specification.required_ruby_version = ">= 3.1"
  specification.files = Dir["lib/**/*.rb"] + %w[README.md LICENSE]
  specification.require_paths = ["lib"]
end
