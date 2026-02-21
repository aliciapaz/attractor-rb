# frozen_string_literal: true

RSpec.describe Attractor::Handlers::CodergenHandler do
  let(:logs_root) { Dir.mktmpdir }
  let(:context) { Attractor::Context.new }
  let(:graph) { Attractor::Graph.new("test", attrs: {"goal" => "Build a feature"}) }

  after { FileUtils.rm_rf(logs_root) }

  describe "with simulation backend" do
    let(:backend) { Attractor::Backends::SimulationBackend.new }
    let(:handler) { described_class.new(backend: backend) }
    let(:node) { Attractor::Node.new("plan", "shape" => "box", "label" => "Plan", "prompt" => "Plan the $goal") }

    it "returns SUCCESS" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
    end

    it "writes prompt.md to logs directory" do
      handler.execute(node, context, graph, logs_root)
      prompt_path = File.join(logs_root, "plan", "prompt.md")
      expect(File.exist?(prompt_path)).to be true
    end

    it "expands $goal in prompt" do
      handler.execute(node, context, graph, logs_root)
      prompt_content = File.read(File.join(logs_root, "plan", "prompt.md"))
      expect(prompt_content).to eq("Plan the Build a feature")
    end

    it "writes response.md to logs directory" do
      handler.execute(node, context, graph, logs_root)
      response_path = File.join(logs_root, "plan", "response.md")
      expect(File.exist?(response_path)).to be true
    end

    it "writes simulated response content" do
      handler.execute(node, context, graph, logs_root)
      response_content = File.read(File.join(logs_root, "plan", "response.md"))
      expect(response_content).to include("[Simulated] Response for: plan")
    end

    it "writes status.json to logs directory" do
      handler.execute(node, context, graph, logs_root)
      status_path = File.join(logs_root, "plan", "status.json")
      expect(File.exist?(status_path)).to be true
    end

    it "sets context_updates with last_stage" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.context_updates["last_stage"]).to eq("plan")
    end

    it "sets context_updates with last_response" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.context_updates["last_response"]).to include("[Simulated]")
    end
  end

  describe "without a backend (simulation mode)" do
    let(:handler) { described_class.new }
    let(:node) { Attractor::Node.new("implement", "shape" => "box", "label" => "Implement") }

    it "returns SUCCESS with simulated response" do
      outcome = handler.execute(node, context, graph, logs_root)
      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
    end

    it "writes simulated response mentioning the node id" do
      handler.execute(node, context, graph, logs_root)
      response_content = File.read(File.join(logs_root, "implement", "response.md"))
      expect(response_content).to eq("[Simulated] Response for stage: implement")
    end
  end

  describe "with a node that has no prompt" do
    let(:handler) { described_class.new(backend: Attractor::Backends::SimulationBackend.new) }
    let(:node) { Attractor::Node.new("review", "shape" => "box", "label" => "Review the code") }

    it "uses label as prompt fallback" do
      handler.execute(node, context, graph, logs_root)
      prompt_content = File.read(File.join(logs_root, "review", "prompt.md"))
      expect(prompt_content).to eq("Review the code")
    end
  end
end
