# frozen_string_literal: true

RSpec.describe Attractor::Handlers::ToolHandler do
  subject(:handler) { described_class.new }

  let(:context) { Attractor::Context.new }
  let(:graph) { Attractor::Graph.new("test") }
  let(:logs_root) { Dir.mktmpdir }

  after { FileUtils.rm_rf(logs_root) }

  describe "with a simple command" do
    let(:node) { Attractor::Node.new("echo_tool", "shape" => "parallelogram", "tool_command" => "echo hello") }

    it "returns SUCCESS" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
    end

    it "captures stdout in context_updates" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.context_updates["tool.output"].strip).to eq("hello")
    end

    it "includes the command in notes" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.notes).to include("echo hello")
    end
  end

  describe "with a failing command" do
    let(:node) { Attractor::Node.new("fail_tool", "shape" => "parallelogram", "tool_command" => "false") }

    it "returns FAIL" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
    end

    it "includes exit status in failure_reason" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.failure_reason).to include("exit")
    end
  end

  describe "with no tool_command" do
    let(:node) { Attractor::Node.new("empty_tool", "shape" => "parallelogram") }

    it "returns FAIL with descriptive message" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
      expect(outcome.failure_reason).to include("No tool_command specified")
    end
  end

  describe "with multi-output command" do
    let(:node) { Attractor::Node.new("multi_tool", "shape" => "parallelogram", "tool_command" => "echo line1 && echo line2") }

    it "captures all output" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.context_updates["tool.output"]).to include("line1")
      expect(outcome.context_updates["tool.output"]).to include("line2")
    end
  end

  describe "file listing capture" do
    context "when tool_command includes a trigger command" do
      # Use "echo bundle" so the command succeeds and contains a trigger word
      let(:node) { Attractor::Node.new("bundle_tool", "shape" => "parallelogram", "tool_command" => "echo bundle exec done") }

      it "captures file listing in context after success" do
        allow(Open3).to receive(:capture3)
          .with("find . -name '*.rb' -not -path './vendor/*' -not -path './node_modules/*' | sort | head -200")
          .and_return(["app/models/user.rb\napp/controllers/users_controller.rb\n", "", instance_double(Process::Status)])

        handler.execute(node, context, graph, logs_root)

        expect(context.get("file_listing")).to eq("app/models/user.rb\napp/controllers/users_controller.rb")
      end
    end

    context "when tool_command includes rails" do
      let(:node) { Attractor::Node.new("rails_tool", "shape" => "parallelogram", "tool_command" => "echo rails generate done") }

      it "triggers file listing capture" do
        allow(Open3).to receive(:capture3)
          .with("find . -name '*.rb' -not -path './vendor/*' -not -path './node_modules/*' | sort | head -200")
          .and_return(["app/models/user.rb\n", "", instance_double(Process::Status)])

        handler.execute(node, context, graph, logs_root)

        expect(context.get("file_listing")).to eq("app/models/user.rb")
      end
    end

    context "when tool_command does not include a trigger" do
      let(:node) { Attractor::Node.new("echo_tool", "shape" => "parallelogram", "tool_command" => "echo hello") }

      it "does not capture file listing" do
        handler.execute(node, context, graph, logs_root)
        expect(context.get("file_listing")).to be_nil
      end
    end

    context "when file listing capture fails" do
      let(:node) { Attractor::Node.new("bundle_tool", "shape" => "parallelogram", "tool_command" => "echo bundle install done") }

      it "does not fail the tool execution" do
        allow(Open3).to receive(:capture3)
          .with("find . -name '*.rb' -not -path './vendor/*' -not -path './node_modules/*' | sort | head -200")
          .and_raise(StandardError, "find not available")

        outcome = handler.execute(node, context, graph, logs_root)
        expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
      end
    end
  end
end
