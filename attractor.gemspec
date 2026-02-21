# frozen_string_literal: true

require_relative "lib/attractor/version"

Gem::Specification.new do |spec|
  spec.name = "attractor-rb"
  spec.version = Attractor::VERSION
  spec.authors = ["Telos"]
  spec.summary = "DOT-based workflow orchestration engine for AI-driven software development"
  spec.description = "Define AI development workflows as Graphviz DOT files and execute them deterministically. " \
    "Orchestrates LLM calls, human approval gates, conditional branching, parallel fan-out/fan-in, " \
    "retry policies with backoff, and checkpoint/resume."
  spec.homepage = "https://github.com/aliciapaz/attractor-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "*.gemspec", "*.md", "LICENSE"]
  spec.bindir = "bin"
  spec.executables = ["attractor"]
  spec.require_paths = ["lib"]

  spec.add_dependency "concurrent-ruby", "~> 1.3"
  spec.add_dependency "thor", "~> 1.3"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
end
