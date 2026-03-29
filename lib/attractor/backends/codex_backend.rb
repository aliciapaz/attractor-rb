# frozen_string_literal: true

require "tempfile"

module Attractor
  module Backends
    class CodexBackend < CodergenBackend
      DEFAULT_TIMEOUT = 300 # 5 minutes
      STDERR_TAIL_LINES = 20

      def self.env_timeout
        raw = ENV["ATTRACTOR_CODEX_TIMEOUT"]
        return DEFAULT_TIMEOUT if raw.nil? || raw.strip.empty?

        Integer(raw, 10)
      rescue ArgumentError
        DEFAULT_TIMEOUT
      end

      def self.env_bool(key, default:)
        raw = ENV[key]
        return default if raw.nil? || raw.strip.empty?

        %w[1 true yes on].include?(raw.strip.downcase)
      end

      def initialize(
        timeout: self.class.env_timeout,
        model: ENV["ATTRACTOR_CODEX_MODEL"],
        profile: ENV["ATTRACTOR_CODEX_PROFILE"],
        sandbox: ENV["ATTRACTOR_CODEX_SANDBOX"],
        full_auto: self.class.env_bool("ATTRACTOR_CODEX_FULL_AUTO", default: true),
        dangerous_bypass: self.class.env_bool("ATTRACTOR_CODEX_DANGEROUS_BYPASS", default: false)
      )
        @timeout = timeout
        @model = model
        @profile = profile
        @sandbox = sandbox
        @full_auto = full_auto
        @dangerous_bypass = dangerous_bypass
      end

      def run(_node, prompt, _context)
        output_file = Tempfile.new(["attractor-codex-output", ".txt"])
        output_file.close

        stdout, stderr, status = capture3_with_timeout(
          @timeout,
          *build_command(prompt, output_file.path)
        )

        if status.success?
          response = File.read(output_file.path)
          return stdout if response.strip.empty?

          response
        else
          raise Error, "Codex failed (exit #{status.exitstatus}): #{trimmed_stderr(stderr)}"
        end
      rescue Errno::ENOENT
        raise Error, "codex CLI not found in PATH"
      rescue Timeout::Error
        raise Error, "Codex timed out after #{@timeout}s"
      ensure
        output_file&.unlink
      end

      private

      def build_command(prompt, output_path)
        command = ["codex", "exec", "--skip-git-repo-check", "--output-last-message", output_path]

        if @dangerous_bypass
          command << "--dangerously-bypass-approvals-and-sandbox"
        else
          command << "--full-auto" if @full_auto
          command += ["--sandbox", @sandbox] if present?(@sandbox)
        end

        command += ["--model", @model] if present?(@model)
        command += ["--profile", @profile] if present?(@profile)
        command << prompt
      end

      def present?(value)
        !value.nil? && !value.strip.empty?
      end

      def trimmed_stderr(stderr)
        lines = stderr.to_s.lines.map(&:rstrip).reject(&:empty?)
        return "no stderr output" if lines.empty?

        lines.last(STDERR_TAIL_LINES).join("\n")
      end

      class Error < StandardError; end
    end
  end
end
