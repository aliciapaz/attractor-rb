# frozen_string_literal: true

module Attractor
  module Backends
    class ClaudeCodeBackend < CodergenBackend
      DEFAULT_TIMEOUT = 300 # 5 minutes

      def initialize(timeout: DEFAULT_TIMEOUT, permission_mode: "bypassPermissions")
        @timeout = timeout
        @permission_mode = permission_mode
      end

      def run(node, prompt, _context)
        env = {"CLAUDECODE" => nil}
        stdout, stderr, status = capture3_with_timeout(
          @timeout,
          env,
          "claude", "--print",
          "--permission-mode", @permission_mode,
          prompt
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

      class Error < StandardError; end
    end
  end
end
