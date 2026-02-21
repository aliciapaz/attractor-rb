# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::Stylesheet::Applicator do
  subject(:applicator) { described_class.new }

  def make_node(id, attrs = {})
    Attractor::Node.new(id, attrs)
  end

  def make_graph(nodes:, stylesheet:)
    node_hash = nodes.each_with_object({}) { |n, h| h[n.id] = n }
    Attractor::Graph.new("test", nodes: node_hash, edges: [], attrs: {"model_stylesheet" => stylesheet})
  end

  describe "#apply" do
    it "applies universal rules to all nodes" do
      stylesheet = "* { llm_model: gpt-4; }"
      nodes = [make_node("A"), make_node("B")]
      graph = make_graph(nodes: nodes, stylesheet: stylesheet)

      applicator.apply(graph)

      expect(graph.nodes["A"].attrs["llm_model"]).to eq("gpt-4")
      expect(graph.nodes["B"].attrs["llm_model"]).to eq("gpt-4")
    end

    it "applies class rules only to nodes with that class" do
      stylesheet = ".code { llm_model: claude-opus-4-6; }"
      nodes = [
        make_node("A", "class" => "code"),
        make_node("B", "class" => "review")
      ]
      graph = make_graph(nodes: nodes, stylesheet: stylesheet)

      applicator.apply(graph)

      expect(graph.nodes["A"].attrs["llm_model"]).to eq("claude-opus-4-6")
      expect(graph.nodes["B"].attrs.key?("llm_model")).to be false
    end

    it "applies ID rules only to the matching node" do
      stylesheet = "#special { reasoning_effort: high; }"
      nodes = [make_node("special"), make_node("other")]
      graph = make_graph(nodes: nodes, stylesheet: stylesheet)

      applicator.apply(graph)

      expect(graph.nodes["special"].attrs["reasoning_effort"]).to eq("high")
      expect(graph.nodes["other"].attrs.key?("reasoning_effort")).to be false
    end

    it "does not override explicit node attributes" do
      stylesheet = "* { llm_model: gpt-4; }"
      nodes = [make_node("A", "llm_model" => "claude-opus-4-6")]
      graph = make_graph(nodes: nodes, stylesheet: stylesheet)

      applicator.apply(graph)

      expect(graph.nodes["A"].attrs["llm_model"]).to eq("claude-opus-4-6")
    end

    it "higher specificity rules override lower ones" do
      stylesheet = <<~CSS
        * { llm_model: gpt-4; }
        .code { llm_model: claude-opus-4-6; }
      CSS
      nodes = [make_node("A", "class" => "code")]
      graph = make_graph(nodes: nodes, stylesheet: stylesheet)

      applicator.apply(graph)

      expect(graph.nodes["A"].attrs["llm_model"]).to eq("claude-opus-4-6")
    end

    it "returns the graph unchanged when stylesheet is empty" do
      nodes = [make_node("A")]
      graph = make_graph(nodes: nodes, stylesheet: "")

      result = applicator.apply(graph)

      expect(result).to eq(graph)
    end
  end
end
