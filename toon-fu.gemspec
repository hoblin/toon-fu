# frozen_string_literal: true

require_relative "lib/toon_fu/version"

Gem::Specification.new do |spec|
  spec.name = "toon-fu"
  spec.version = ToonFu::VERSION
  spec.authors = ["Yevhenii Hurin"]
  spec.email = ["evgeny.gurin@gmail.com"]

  spec.summary = "TOON (Token-Oriented Object Notation) for Ruby, versioned by the spec it implements"
  spec.description = "A Ruby implementation of TOON, the token-efficient serialization format for LLM input. " \
                     "The gem's MAJOR.MINOR tracks the TOON specification version; PATCH is the gem's own."
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
