# frozen_string_literal: true

require_relative "lib/toon_fu/version"

Gem::Specification.new do |spec|
  spec.name = "toon-fu"
  spec.version = ToonFu::VERSION
  spec.authors = ["Yevhenii Hurin"]
  spec.email = ["evgeny.gurin@gmail.com"]

  spec.summary = "TOON encoder for Ruby that passes every spec fixture — compact, token-efficient LLM input from your Ruby data"
  spec.description = "Encodes Ruby hashes, arrays, dates and your own objects into TOON, the token-efficient format " \
                     "for LLM prompts: tables for uniform arrays, quotes only where needed. The only Ruby TOON gem " \
                     "that passes all of the current spec's encode fixtures; its version tracks the spec it implements, " \
                     "and anything it cannot represent raises an error so your data arrives complete."
  spec.homepage = "https://github.com/hoblin/toon-fu"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "source_code_uri" => "https://github.com/hoblin/toon-fu",
    "changelog_uri" => "https://github.com/hoblin/toon-fu/releases",
    "documentation_uri" => "https://rubydoc.info/gems/toon-fu",
    "bug_tracker_uri" => "https://github.com/hoblin/toon-fu/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.glob("lib/**/*") + %w[README.md LICENSE]
  spec.require_paths = ["lib"]
end
