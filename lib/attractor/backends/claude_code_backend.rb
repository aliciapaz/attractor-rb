# frozen_string_literal: true

module Attractor
  module Backends
    class ClaudeCodeBackend < CodergenBackend
      DEFAULT_TIMEOUT = 300 # 5 minutes

      def initialize(timeout: DEFAULT_TIMEOUT, permission_mode: "bypassPermissions")
        @timeout = timeout
        @permission_mode = permission_mode
      end

      def run(node, prompt, context)
        full_prompt = prepend_file_listing(prompt, context)
        env = {"CLAUDECODE" => nil}
        stdout, stderr, status = capture3_with_timeout(
          @timeout,
          env,
          "claude", "--print",
          "--permission-mode", @permission_mode,
          full_prompt
        )

        if status.success?
          stdout
        else
          raise Error, "Claude Code failed (exit #{status.exitstatus}): #{stderr.strip}"
        end
      rescue Errno::ENOENT
        raise Error, "claude CLI not found in PATH"
      rescue Timeout::Error
        raise Error, "Claude Code timed out after #{@timeout}s"
      end

      private

      def prepend_file_listing(prompt, context)
        return prompt unless context.respond_to?(:get)

        listing = context.get("file_listing")
        return prompt unless listing && !listing.empty?

        "Current project files:\n#{listing}\n\n#{prompt}"
      end

      class Error < StandardError; end
    end
  end
end
