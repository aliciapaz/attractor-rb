# frozen_string_literal: true

module Attractor
  module Handlers
    class ToolHandler < BaseHandler
      include ProcessHelper

      DEFAULT_TIMEOUT = 60 # seconds

      def execute(node, context, _graph, _logs_root)
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
            maybe_capture_file_listing(context, command)
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

      FILE_LISTING_TRIGGERS = %w[rails bundle rake db:migrate db:create].freeze

      def maybe_capture_file_listing(context, command)
        return unless should_capture_listing?(command)

        listing, _stderr, _status = Open3.capture3(
          "find . -name '*.rb' -not -path './vendor/*' -not -path './node_modules/*' | sort | head -200"
        )
        context.set("file_listing", listing.strip) if listing && !listing.empty?
      rescue StandardError
        # File listing is best-effort; don't fail the tool
      end

      def should_capture_listing?(command)
        FILE_LISTING_TRIGGERS.any? { |trigger| command.include?(trigger) }
      end

      def execute_command(command, timeout)
        Bundler.with_unbundled_env do
          capture3_with_timeout(timeout, "sh", "-c", command)
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
