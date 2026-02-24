# frozen_string_literal: true

require "thor"
require_relative "cli/run_command"
require_relative "cli/validate_command"

module Attractor
  class CLI < Thor
    desc "run DOTFILE", "Execute a pipeline from a DOT file"
    option :logs_root, type: :string, default: "./logs", desc: "Directory for logs and artifacts"
    option :backend, type: :string, default: "simulation", desc: "Backend: simulation, claude, codex"
    option :interviewer, type: :string, default: "auto_approve", desc: "Interviewer: auto_approve, console"
    option :resume, type: :boolean, default: false, desc: "Resume from checkpoint"
    def run_pipeline(dotfile)
      Cli::RunCommand.new(dotfile, options).execute
    end

    desc "validate DOTFILE", "Validate a pipeline DOT file"
    def validate(dotfile)
      Cli::ValidateCommand.new(dotfile).execute
    end

    map "run" => :run_pipeline
  end
end
