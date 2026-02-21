# frozen_string_literal: true

module Attractor
  module Cli
    class RunCommand
      def initialize(dotfile, options)
        @dotfile = dotfile
        @options = options
      end

      def execute
        source = read_dotfile
        backend = build_backend
        interviewer = build_interviewer
        logs_root = @options[:logs_root] || "./logs"
        resume = @options[:resume] || false

        engine = Engine.new(
          backend: backend,
          interviewer: interviewer
        )

        outcome = engine.run(source, logs_root: logs_root, resume: resume)

        if outcome.success?
          $stdout.puts "Pipeline completed successfully."
          $stdout.puts "Status: #{outcome.status}"
          $stdout.puts "Notes: #{outcome.notes}" unless outcome.notes.empty?
        else
          warn "Pipeline failed."
          warn "Status: #{outcome.status}"
          warn "Reason: #{outcome.failure_reason}" unless outcome.failure_reason.empty?
          exit 1
        end
      rescue Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      private

      def read_dotfile
        unless File.exist?(@dotfile)
          raise Error, "DOT file not found: #{@dotfile}"
        end

        File.read(@dotfile)
      end

      def build_backend
        case @options[:backend]
        when "simulation"
          Backends::SimulationBackend.new
        when "claude"
          Backends::ClaudeCodeBackend.new
        else
          Backends::SimulationBackend.new
        end
      end

      def build_interviewer
        case @options[:interviewer]
        when "auto_approve"
          Interviewer::AutoApprove.new
        when "console"
          Interviewer::Console.new
        else
          Interviewer::AutoApprove.new
        end
      end
    end
  end
end
