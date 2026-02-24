# frozen_string_literal: true

RSpec.describe Attractor::Backends::ClaudeCodeBackend do
  let(:node) { Attractor::Node.new("plan", "shape" => "box", "label" => "Plan") }
  let(:context) { Attractor::Context.new }

  describe "#run" do
    context "when claude CLI succeeds" do
      it "returns stdout" do
        status = instance_double(Process::Status, success?: true)
        stub_popen3(stdout: "response text", status: status)

        backend = described_class.new
        result = backend.run(node, "Build a feature", context)

        expect(result).to eq("response text")
        expect(Open3).to have_received(:popen3).with(
          {"CLAUDECODE" => nil},
          "claude", "--print",
          "--permission-mode", "bypassPermissions",
          "Build a feature"
        )
      end
    end

    context "when claude CLI fails" do
      it "raises Error with exit status and stderr" do
        status = instance_double(Process::Status, success?: false, exitstatus: 1)
        stub_popen3(stderr: "something went wrong", status: status)

        backend = described_class.new

        expect { backend.run(node, "prompt", context) }
          .to raise_error(Attractor::Backends::ClaudeCodeBackend::Error, /exit 1.*something went wrong/)
      end
    end

    context "when claude CLI is not found" do
      it "raises Error" do
        allow(Open3).to receive(:popen3).and_raise(Errno::ENOENT)

        backend = described_class.new

        expect { backend.run(node, "prompt", context) }
          .to raise_error(Attractor::Backends::ClaudeCodeBackend::Error, /not found in PATH/)
      end
    end

    context "when claude CLI times out" do
      it "raises Error with timeout message" do
        stub_popen3_hanging
        allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
        allow(Process).to receive(:kill).and_raise(Errno::ESRCH)

        backend = described_class.new(timeout: 10)

        expect { backend.run(node, "prompt", context) }
          .to raise_error(Attractor::Backends::ClaudeCodeBackend::Error, /timed out after 10s/)
      end
    end
  end

  def stub_popen3(stdout: "", stderr: "", status:)
    wait_thr = double("wait_thr", pid: 12345, value: status)
    allow(Open3).to receive(:popen3).and_return(
      [StringIO.new, StringIO.new(stdout), StringIO.new(stderr), wait_thr]
    )
  end

  def stub_popen3_hanging
    wait_thr = double("wait_thr", pid: 12345, value: nil)
    allow(Open3).to receive(:popen3).and_return(
      [StringIO.new, StringIO.new, StringIO.new, wait_thr]
    )
  end
end
