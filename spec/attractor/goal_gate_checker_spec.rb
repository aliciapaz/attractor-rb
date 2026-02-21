# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::GoalGateChecker do
  subject(:checker) { described_class.new }

  def make_node(id, attrs = {})
    Attractor::Node.new(id, attrs)
  end

  def make_graph(nodes:, edges: [], attrs: {})
    node_hash = nodes.each_with_object({}) { |n, h| h[n.id] = n }
    Attractor::Graph.new("test", nodes: node_hash, edges: edges, attrs: attrs)
  end

  def success_outcome
    Attractor::Outcome.new(status: Attractor::StageStatus::SUCCESS)
  end

  def fail_outcome
    Attractor::Outcome.new(status: Attractor::StageStatus::FAIL, failure_reason: "tests failed")
  end

  describe "#check" do
    it "returns [true, nil] when no goal gates exist" do
      graph = make_graph(nodes: [make_node("A"), make_node("B")])

      ok, failed = checker.check(graph, {"A" => success_outcome})

      expect(ok).to be true
      expect(failed).to be_nil
    end

    it "returns [true, nil] when all goal gates are satisfied" do
      nodes = [
        make_node("A", "goal_gate" => true),
        make_node("B", "goal_gate" => true)
      ]
      graph = make_graph(nodes: nodes)
      outcomes = {
        "A" => success_outcome,
        "B" => success_outcome
      }

      ok, failed = checker.check(graph, outcomes)

      expect(ok).to be true
      expect(failed).to be_nil
    end

    it "returns [false, failed_node] when a goal gate is not satisfied" do
      nodes = [
        make_node("A", "goal_gate" => true),
        make_node("B", "goal_gate" => true)
      ]
      graph = make_graph(nodes: nodes)
      outcomes = {
        "A" => success_outcome,
        "B" => fail_outcome
      }

      ok, failed = checker.check(graph, outcomes)

      expect(ok).to be false
      expect(failed.id).to eq("B")
    end

    it "returns [false, failed_node] when goal gate node has no outcome" do
      nodes = [make_node("A", "goal_gate" => true)]
      graph = make_graph(nodes: nodes)

      ok, failed = checker.check(graph, {})

      expect(ok).to be false
      expect(failed.id).to eq("A")
    end

    it "treats partial_success as satisfied" do
      nodes = [make_node("A", "goal_gate" => true)]
      graph = make_graph(nodes: nodes)
      outcomes = {
        "A" => Attractor::Outcome.new(status: Attractor::StageStatus::PARTIAL_SUCCESS)
      }

      ok, _failed = checker.check(graph, outcomes)

      expect(ok).to be true
    end
  end

  describe "#retry_target" do
    it "returns node retry_target when set" do
      node = make_node("A", "retry_target" => "plan")
      graph = make_graph(nodes: [node])

      expect(checker.retry_target(node, graph)).to eq("plan")
    end

    it "returns node fallback_retry_target when retry_target is empty" do
      node = make_node("A", "fallback_retry_target" => "fallback")
      graph = make_graph(nodes: [node])

      expect(checker.retry_target(node, graph)).to eq("fallback")
    end

    it "returns graph retry_target when node targets are empty" do
      node = make_node("A")
      graph = make_graph(nodes: [node], attrs: {"retry_target" => "graph_retry"})

      expect(checker.retry_target(node, graph)).to eq("graph_retry")
    end

    it "returns graph fallback_retry_target as last resort" do
      node = make_node("A")
      graph = make_graph(nodes: [node], attrs: {"fallback_retry_target" => "graph_fallback"})

      expect(checker.retry_target(node, graph)).to eq("graph_fallback")
    end

    it "returns nil when no retry target exists at any level" do
      node = make_node("A")
      graph = make_graph(nodes: [node])

      expect(checker.retry_target(node, graph)).to be_nil
    end
  end
end
