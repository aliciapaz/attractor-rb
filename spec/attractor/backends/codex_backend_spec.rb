# frozen_string_literal: true

RSpec.describe Attractor::Backends::CodexBackend do
  let(:node) { Attractor::Node.new("plan", "shape" => "box", "label" => "Plan") }
  let(:context) { Attractor::Context.new }

  describe "#run" do
    it "returns the final assistant message from output file" do
      status = instance_double(Process::Status, success?: true)
      captured_args = nil

      allow(Open3).to receive(:popen3) do |*args|
        captured_args = args
        output_path = args[args.index("--output-last-message") + 1]
        File.write(output_path, "final answer")
        [StringIO.new, StringIO.new("session banner"), StringIO.new(""),
         double("wait_thr", pid: 12345, value: status)]
      end

      result = described_class.new.run(node, "Build a feature", context)

      expect(result).to eq("final answer")
      expect(captured_args.first(3)).to eq(["codex", "exec", "--skip-git-repo-check"])
      expect(captured_args).to include("--output-last-message")
      expect(captured_args).to include("--full-auto")
      expect(captured_args).to include("Build a feature")
    end

    it "falls back to stdout when output-last-message file is empty" do
      status = instance_double(Process::Status, success?: true)

      allow(Open3).to receive(:popen3) do |*args|
        output_path = args[args.index("--output-last-message") + 1]
        File.write(output_path, " \n")
        [StringIO.new, StringIO.new("stdout response"), StringIO.new(""),
         double("wait_thr", pid: 12345, value: status)]
      end

      result = described_class.new.run(node, "Build a feature", context)

      expect(result).to eq("stdout response")
    end

    it "raises Error when codex CLI fails" do
      status = instance_double(Process::Status, success?: false, exitstatus: 7)
      wait_thr = double("wait_thr", pid: 12345, value: status)
      allow(Open3).to receive(:popen3).and_return(
        [StringIO.new, StringIO.new(""), StringIO.new("line 1\nline 2\n"), wait_thr]
      )

      expect { described_class.new.run(node, "prompt", context) }
        .to raise_error(Attractor::Backends::CodexBackend::Error, /exit 7.*line 1.*line 2/m)
    end

    it "raises Error when codex CLI is not found" do
      allow(Open3).to receive(:popen3).and_raise(Errno::ENOENT)

      expect { described_class.new.run(node, "prompt", context) }
        .to raise_error(Attractor::Backends::CodexBackend::Error, /not found in PATH/)
    end

    it "raises Error on timeout" do
      wait_thr = double("wait_thr", pid: 12345, value: nil)
      allow(Open3).to receive(:popen3).and_return(
        [StringIO.new, StringIO.new, StringIO.new, wait_thr]
      )
      allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)

      expect { described_class.new(timeout: 10).run(node, "prompt", context) }
        .to raise_error(Attractor::Backends::CodexBackend::Error, /timed out after 10s/)
    end

    it "composes flags from environment overrides" do
      with_env(
        "ATTRACTOR_CODEX_MODEL" => "gpt-5",
        "ATTRACTOR_CODEX_PROFILE" => "ci",
        "ATTRACTOR_CODEX_SANDBOX" => "read-only",
        "ATTRACTOR_CODEX_FULL_AUTO" => "false",
        "ATTRACTOR_CODEX_DANGEROUS_BYPASS" => "true",
        "ATTRACTOR_CODEX_TIMEOUT" => "42"
      ) do
        status = instance_double(Process::Status, success?: true)
        captured_args = nil

        allow(Open3).to receive(:popen3) do |*args|
          captured_args = args
          output_path = args[args.index("--output-last-message") + 1]
          File.write(output_path, "from env")
          [StringIO.new, StringIO.new(""), StringIO.new(""),
           double("wait_thr", pid: 12345, value: status)]
        end

        expect(Timeout).to receive(:timeout).with(42).and_call_original

        result = described_class.new.run(node, "Build a feature", context)

        expect(result).to eq("from env")
        expect(captured_args).to include("--dangerously-bypass-approvals-and-sandbox")
        expect(captured_args).to include("--model", "gpt-5")
        expect(captured_args).to include("--profile", "ci")
        expect(captured_args).not_to include("--full-auto")
        expect(captured_args).not_to include("--sandbox")
      end
    end
  end

  def with_env(values)
    original = {}
    values.each do |key, value|
      original[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
