# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::EdgeSelector do
  subject(:selector) { described_class.new }

  let(:context) { Attractor::Context.new }

  def make_node(id, attrs = {})
    Attractor::Node.new(id, attrs)
  end

  def make_edge(from, to, attrs = {})
    Attractor::Edge.new(from, to, attrs)
  end

  def make_outcome(status: Attractor::StageStatus::SUCCESS, preferred_label: "", suggested_next_ids: [])
    Attractor::Outcome.new(
      status: status,
      preferred_label: preferred_label,
      suggested_next_ids: suggested_next_ids
    )
  end

  def make_graph(nodes:, edges:)
    node_hash = nodes.each_with_object({}) { |n, h| h[n.id] = n }
    Attractor::Graph.new("test", nodes: node_hash, edges: edges)
  end

  describe "#select" do
    context "when there are no outgoing edges" do
      it "returns nil" do
        node = make_node("A")
        graph = make_graph(nodes: [node], edges: [])
        outcome = make_outcome

        result = selector.select(node, outcome, context, graph)

        expect(result).to be_nil
      end
    end

    context "Step 1: condition matching" do
      it "selects the edge whose condition matches" do
        node = make_node("A")
        edge_yes = make_edge("A", "B", "condition" => "outcome=success", "label" => "Yes")
        edge_no = make_edge("A", "C", "condition" => "outcome=fail", "label" => "No")
        graph = make_graph(nodes: [node, make_node("B"), make_node("C")], edges: [edge_yes, edge_no])
        outcome = make_outcome(status: Attractor::StageStatus::SUCCESS)

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("B")
      end

      it "selects the highest-weight condition match when multiple match" do
        node = make_node("A")
        edge_low = make_edge("A", "B", "condition" => "outcome=success", "weight" => 1)
        edge_high = make_edge("A", "C", "condition" => "outcome=success", "weight" => 5)
        graph = make_graph(nodes: [node, make_node("B"), make_node("C")], edges: [edge_low, edge_high])
        outcome = make_outcome(status: Attractor::StageStatus::SUCCESS)

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("C")
      end
    end

    context "Step 2: preferred label" do
      it "selects the edge matching the preferred label" do
        node = make_node("A")
        edge_b = make_edge("A", "B", "label" => "Approve")
        edge_c = make_edge("A", "C", "label" => "Reject")
        graph = make_graph(nodes: [node, make_node("B"), make_node("C")], edges: [edge_b, edge_c])
        outcome = make_outcome(preferred_label: "Approve")

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("B")
      end

      it "normalizes labels with accelerator prefixes" do
        node = make_node("A")
        edge_b = make_edge("A", "B", "label" => "[Y] Yes, deploy")
        edge_c = make_edge("A", "C", "label" => "[N] No, rollback")
        graph = make_graph(nodes: [node, make_node("B"), make_node("C")], edges: [edge_b, edge_c])
        outcome = make_outcome(preferred_label: "yes, deploy")

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("B")
      end

      it "normalizes labels with parenthesis accelerator" do
        node = make_node("A")
        edge_b = make_edge("A", "B", "label" => "Y) Yes")
        graph = make_graph(nodes: [node, make_node("B")], edges: [edge_b])
        outcome = make_outcome(preferred_label: "yes")

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("B")
      end
    end

    context "Step 3: suggested next IDs" do
      it "selects the first matching suggested next ID" do
        node = make_node("A")
        edge_b = make_edge("A", "B")
        edge_c = make_edge("A", "C")
        graph = make_graph(nodes: [node, make_node("B"), make_node("C")], edges: [edge_b, edge_c])
        outcome = make_outcome(suggested_next_ids: ["C", "B"])

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("C")
      end

      it "falls through when no suggested IDs match" do
        node = make_node("A")
        edge_b = make_edge("A", "B")
        graph = make_graph(nodes: [node, make_node("B")], edges: [edge_b])
        outcome = make_outcome(suggested_next_ids: ["Z"])

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("B")
      end
    end

    context "Step 4 & 5: weight with lexical tiebreak" do
      it "selects the highest-weight unconditional edge" do
        node = make_node("A")
        edge_b = make_edge("A", "B", "weight" => 1)
        edge_c = make_edge("A", "C", "weight" => 5)
        graph = make_graph(nodes: [node, make_node("B"), make_node("C")], edges: [edge_b, edge_c])
        outcome = make_outcome

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("C")
      end

      it "breaks ties lexicographically by target node ID" do
        node = make_node("A")
        edge_b = make_edge("A", "B", "weight" => 0)
        edge_c = make_edge("A", "C", "weight" => 0)
        graph = make_graph(nodes: [node, make_node("B"), make_node("C")], edges: [edge_b, edge_c])
        outcome = make_outcome

        result = selector.select(node, outcome, context, graph)

        expect(result.to).to eq("B")
      end
    end

    context "when all edges are conditional and none match" do
      it "returns nil instead of selecting an unmatched conditional edge" do
        node = make_node("A")
        edge_b = make_edge("A", "B", "condition" => "outcome=retry", "weight" => 1)
        edge_c = make_edge("A", "C", "condition" => "outcome=retry", "weight" => 5)
        graph = make_graph(nodes: [node, make_node("B"), make_node("C")], edges: [edge_b, edge_c])
        outcome = make_outcome(status: Attractor::StageStatus::SUCCESS)

        result = selector.select(node, outcome, context, graph)

        expect(result).to be_nil
      end
    end
  end
end
