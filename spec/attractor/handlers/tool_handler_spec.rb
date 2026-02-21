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
end
