# frozen_string_literal: true

RSpec.describe Attractor::Backends::ClaudeCodeBackend do
  let(:node) { Attractor::Node.new("plan", "shape" => "box", "label" => "Plan") }
  let(:context) { Attractor::Context.new }

  describe "#run" do
    context "when claude CLI succeeds" do
      it "returns stdout" do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3)
          .with("claude", "--print", "Build a feature")
          .and_return(["response text", "", status])

        backend = described_class.new
        result = backend.run(node, "Build a feature", context)

        expect(result).to eq("response text")
      end
    end

    context "when claude CLI fails" do
      it "raises Error with exit status and stderr" do
        status = instance_double(Process::Status, success?: false, exitstatus: 1)
        allow(Open3).to receive(:capture3)
          .and_return(["", "something went wrong", status])

        backend = described_class.new

        expect { backend.run(node, "prompt", context) }
          .to raise_error(Attractor::Backends::ClaudeCodeBackend::Error, /exit 1.*something went wrong/)
      end
    end

    context "when claude CLI is not found" do
      it "raises Error" do
        allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

        backend = described_class.new

        expect { backend.run(node, "prompt", context) }
          .to raise_error(Attractor::Backends::ClaudeCodeBackend::Error, /not found in PATH/)
      end
    end

    context "when claude CLI times out" do
      it "raises Error with timeout message" do
        allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)

        backend = described_class.new(timeout: 10)

        expect { backend.run(node, "prompt", context) }
          .to raise_error(Attractor::Backends::ClaudeCodeBackend::Error, /timed out after 10s/)
      end
    end
  end
end
