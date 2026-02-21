# frozen_string_literal: true

module Attractor
  module Handlers
    class ToolHandler < BaseHandler
      DEFAULT_TIMEOUT = 60 # seconds

      def execute(node, _context, _graph, _logs_root)
        command = node.attrs.fetch("tool_command", "").to_s

        if command.empty?
          return Outcome.new(
            status: StageStatus::FAIL,
            failure_reason: "No tool_command specified"
          )
        end

        timeout = resolve_timeout(node)

        begin
          stdout, stderr, status = execute_command(command, timeout)

          if status.success?
            Outcome.new(
              status: StageStatus::SUCCESS,
              context_updates: {"tool.output" => stdout},
              notes: "Tool completed: #{command}"
            )
          else
            Outcome.new(
              status: StageStatus::FAIL,
              failure_reason: "Command failed (exit #{status.exitstatus}): #{stderr.strip}",
              context_updates: {"tool.output" => stdout}
            )
          end
        rescue => e
          Outcome.new(
            status: StageStatus::FAIL,
            failure_reason: "Tool execution error: #{e.message}"
          )
        end
      end

      private

      # Runs command via shell. DOT files that use tool_command are trusted
      # input — the pipeline author controls what commands run, similar to
      # a Makefile or CI config. Do not run untrusted DOT files.
      def execute_command(command, timeout)
        Timeout.timeout(timeout) do
          Open3.capture3("sh", "-c", command)
        end
      rescue Timeout::Error
        raise StandardError, "Command timed out after #{timeout}s"
      end

      def resolve_timeout(node)
        raw = node.timeout
        return DEFAULT_TIMEOUT if raw.nil?

        return DEFAULT_TIMEOUT unless raw.is_a?(Numeric)

        # AttributeTypes coerces duration strings to milliseconds.
        # Convert to seconds for Timeout.timeout.
        raw / 1000.0
      end
    end
  end
end
