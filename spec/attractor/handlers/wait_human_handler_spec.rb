# frozen_string_literal: true

RSpec.describe Attractor::Handlers::WaitHumanHandler do
  let(:logs_root) { Dir.mktmpdir }
  let(:context) { Attractor::Context.new }

  after { FileUtils.rm_rf(logs_root) }

  def build_graph_with_edges(node_id, edge_specs)
    graph = Attractor::Graph.new("test")
    graph.add_node(Attractor::Node.new(node_id, "shape" => "hexagon", "label" => "Review Changes"))
    edge_specs.each do |spec|
      target = Attractor::Node.new(spec[:to], "label" => spec[:to])
      graph.add_node(target)
      graph.add_edge(Attractor::Edge.new(node_id, spec[:to], "label" => spec[:label]))
    end
    graph
  end

  describe "with queue interviewer selecting a choice" do
    let(:graph) do
      build_graph_with_edges("review_gate", [
        {to: "ship_it", label: "[A] Approve"},
        {to: "fixes", label: "[F] Fix"}
      ])
    end
    let(:node) { graph.nodes["review_gate"] }

    it "routes to the selected choice" do
      answer = Attractor::Answer.new(value: "A")
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
      expect(outcome.suggested_next_ids).to eq(["ship_it"])
    end

    it "routes to second choice when selected" do
      answer = Attractor::Answer.new(value: "F")
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
      expect(outcome.suggested_next_ids).to eq(["fixes"])
    end

    it "sets human.gate.selected in context_updates" do
      answer = Attractor::Answer.new(value: "A")
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.context_updates["human.gate.selected"]).to eq("A")
    end

    it "sets human.gate.label in context_updates" do
      answer = Attractor::Answer.new(value: "A")
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.context_updates["human.gate.label"]).to eq("[A] Approve")
    end
  end

  describe "when interviewer returns SKIPPED" do
    let(:graph) do
      build_graph_with_edges("review_gate", [
        {to: "ship_it", label: "[A] Approve"}
      ])
    end
    let(:node) { graph.nodes["review_gate"] }

    it "returns FAIL" do
      interviewer = Attractor::Interviewer::Queue.new(answers: [])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
      expect(outcome.failure_reason).to include("skipped")
    end
  end

  describe "when interviewer returns TIMEOUT" do
    let(:graph) do
      build_graph_with_edges("review_gate", [
        {to: "ship_it", label: "[A] Approve"},
        {to: "fixes", label: "[F] Fix"}
      ])
    end

    it "returns RETRY when no default choice configured" do
      node = graph.nodes["review_gate"]
      answer = Attractor::Answer.new(value: Attractor::AnswerValue::TIMEOUT)
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::RETRY)
    end

    it "uses default choice when configured" do
      node = Attractor::Node.new("review_gate", {
        "shape" => "hexagon",
        "label" => "Review Changes",
        "human.default_choice" => "A"
      })
      graph.add_node(node)

      answer = Attractor::Answer.new(value: Attractor::AnswerValue::TIMEOUT)
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::SUCCESS)
      expect(outcome.suggested_next_ids).to eq(["ship_it"])
    end
  end

  describe "with no outgoing edges" do
    let(:graph) { Attractor::Graph.new("test") }
    let(:node) { Attractor::Node.new("orphan", "shape" => "hexagon", "label" => "Orphan") }

    before { graph.add_node(node) }

    it "returns FAIL" do
      interviewer = Attractor::Interviewer::AutoApprove.new
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
      expect(outcome.failure_reason).to include("No outgoing edges")
    end
  end

  describe "accelerator key parsing" do
    it "extracts key from [K] Label pattern" do
      graph = build_graph_with_edges("gate", [
        {to: "target", label: "[Y] Yes, deploy"}
      ])
      node = graph.nodes["gate"]
      answer = Attractor::Answer.new(value: "Y")
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.context_updates["human.gate.selected"]).to eq("Y")
    end

    it "extracts key from K) Label pattern" do
      graph = build_graph_with_edges("gate", [
        {to: "target", label: "Y) Yes, deploy"}
      ])
      node = graph.nodes["gate"]
      answer = Attractor::Answer.new(value: "Y")
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.context_updates["human.gate.selected"]).to eq("Y")
    end

    it "uses first character when no accelerator pattern found" do
      graph = build_graph_with_edges("gate", [
        {to: "target", label: "Deploy now"}
      ])
      node = graph.nodes["gate"]
      answer = Attractor::Answer.new(value: "D")
      interviewer = Attractor::Interviewer::Queue.new(answers: [answer])
      handler = described_class.new(interviewer: interviewer)

      outcome = handler.execute(node, context, graph, logs_root)

      expect(outcome.context_updates["human.gate.selected"]).to eq("D")
    end
  end
end
