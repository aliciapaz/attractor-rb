# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::Validator do
  subject(:validator) { described_class.new }

  def build_graph(name: "test", nodes: {}, edges: [], attrs: {})
    Attractor::Graph.new(name, nodes: nodes, edges: edges, attrs: attrs)
  end

  def build_node(id, **overrides)
    attrs = overrides.transform_keys(&:to_s)
    Attractor::Node.new(id, attrs)
  end

  def build_edge(from, to, **overrides)
    attrs = overrides.transform_keys(&:to_s)
    Attractor::Edge.new(from, to, attrs)
  end

  def valid_pipeline
    start = build_node("start", shape: "Mdiamond")
    work = build_node("work", type: "codergen", prompt: "Do work")
    finish = build_node("exit", shape: "Msquare")
    nodes = {"start" => start, "work" => work, "exit" => finish}
    edges = [build_edge("start", "work"), build_edge("work", "exit")]
    build_graph(nodes: nodes, edges: edges)
  end

  describe "#validate" do
    it "returns no errors for a valid pipeline" do
      diagnostics = validator.validate(valid_pipeline)
      errors = diagnostics.select(&:error?)
      expect(errors).to be_empty
    end

    it "runs extra rules when provided" do
      custom_rule = Class.new(Attractor::LintRules::BaseRule) do
        def name = "custom"

        def apply(_graph)
          [Attractor::Diagnostic.new(
            rule: name, severity: Attractor::Diagnostic::SEVERITY_INFO, message: "custom info"
          )]
        end
      end.new

      diagnostics = validator.validate(valid_pipeline, extra_rules: [custom_rule])
      info = diagnostics.select(&:info?)
      expect(info.size).to eq(1)
      expect(info.first.rule).to eq("custom")
    end
  end

  describe "#validate_or_raise" do
    it "returns diagnostics when no errors" do
      result = validator.validate_or_raise(valid_pipeline)
      expect(result).to be_an(Array)
    end

    it "raises ValidationError when errors exist" do
      graph = build_graph(nodes: {}, edges: [])
      expect { validator.validate_or_raise(graph) }.to raise_error(Attractor::ValidationError)
    end
  end

  describe "StartNodeRule" do
    it "errors when no start node exists" do
      graph = build_graph(
        nodes: {"exit" => build_node("exit", shape: "Msquare")},
        edges: []
      )
      diagnostics = validator.validate(graph)
      start_errors = diagnostics.select { |d| d.rule == "start_node" && d.error? }
      expect(start_errors.size).to eq(1)
    end

    it "errors when multiple start nodes exist" do
      graph = build_graph(
        nodes: {
          "s1" => build_node("s1", shape: "Mdiamond"),
          "s2" => build_node("s2", shape: "Mdiamond"),
          "exit" => build_node("exit", shape: "Msquare")
        },
        edges: [build_edge("s1", "exit"), build_edge("s2", "exit")]
      )
      diagnostics = validator.validate(graph)
      start_errors = diagnostics.select { |d| d.rule == "start_node" && d.error? }
      expect(start_errors.size).to eq(1)
    end

    it "passes with exactly one start node" do
      diagnostics = validator.validate(valid_pipeline)
      start_errors = diagnostics.select { |d| d.rule == "start_node" }
      expect(start_errors).to be_empty
    end
  end

  describe "TerminalNodeRule" do
    it "errors when no terminal node exists" do
      graph = build_graph(
        nodes: {"start" => build_node("start", shape: "Mdiamond")},
        edges: []
      )
      diagnostics = validator.validate(graph)
      terminal_errors = diagnostics.select { |d| d.rule == "terminal_node" && d.error? }
      expect(terminal_errors.size).to eq(1)
    end

    it "passes with at least one terminal node" do
      diagnostics = validator.validate(valid_pipeline)
      terminal_errors = diagnostics.select { |d| d.rule == "terminal_node" }
      expect(terminal_errors).to be_empty
    end
  end

  describe "ReachabilityRule" do
    it "errors for unreachable nodes" do
      island = build_node("island", type: "codergen", prompt: "isolated")
      start = build_node("start", shape: "Mdiamond")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "exit" => finish, "island" => island}
      edges = [build_edge("start", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      reach_errors = diagnostics.select { |d| d.rule == "reachability" && d.error? }
      expect(reach_errors.size).to eq(1)
      expect(reach_errors.first.node_id).to eq("island")
    end

    it "passes when all nodes are reachable" do
      diagnostics = validator.validate(valid_pipeline)
      reach_errors = diagnostics.select { |d| d.rule == "reachability" }
      expect(reach_errors).to be_empty
    end
  end

  describe "EdgeTargetExistsRule" do
    it "errors for edges referencing non-existent nodes" do
      start = build_node("start", shape: "Mdiamond")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "exit" => finish}
      edges = [build_edge("start", "exit"), build_edge("start", "ghost")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      target_errors = diagnostics.select { |d| d.rule == "edge_target_exists" && d.error? }
      expect(target_errors.size).to eq(1)
      expect(target_errors.first.message).to include("ghost")
    end

    it "errors for edges with non-existent source nodes" do
      start = build_node("start", shape: "Mdiamond")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "exit" => finish}
      edges = [build_edge("start", "exit"), build_edge("phantom", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      target_errors = diagnostics.select { |d| d.rule == "edge_target_exists" && d.error? }
      expect(target_errors.size).to eq(1)
      expect(target_errors.first.message).to include("phantom")
    end

    it "passes when all edge targets exist" do
      diagnostics = validator.validate(valid_pipeline)
      target_errors = diagnostics.select { |d| d.rule == "edge_target_exists" }
      expect(target_errors).to be_empty
    end
  end

  describe "StartNoIncomingRule" do
    it "errors when start node has incoming edges" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [
        build_edge("start", "work"),
        build_edge("work", "exit"),
        build_edge("work", "start")
      ]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      incoming_errors = diagnostics.select { |d| d.rule == "start_no_incoming" && d.error? }
      expect(incoming_errors.size).to eq(1)
    end

    it "passes when start node has no incoming edges" do
      diagnostics = validator.validate(valid_pipeline)
      incoming_errors = diagnostics.select { |d| d.rule == "start_no_incoming" }
      expect(incoming_errors).to be_empty
    end
  end

  describe "ExitNoOutgoingRule" do
    it "errors when exit node has outgoing edges" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [
        build_edge("start", "work"),
        build_edge("work", "exit"),
        build_edge("exit", "work")
      ]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      outgoing_errors = diagnostics.select { |d| d.rule == "exit_no_outgoing" && d.error? }
      expect(outgoing_errors.size).to eq(1)
    end

    it "passes when exit node has no outgoing edges" do
      diagnostics = validator.validate(valid_pipeline)
      outgoing_errors = diagnostics.select { |d| d.rule == "exit_no_outgoing" }
      expect(outgoing_errors).to be_empty
    end
  end

  describe "ConditionSyntaxRule" do
    it "errors for invalid condition syntax" do
      start = build_node("start", shape: "Mdiamond")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "exit" => finish}
      edges = [build_edge("start", "exit", condition: "&&")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      cond_errors = diagnostics.select { |d| d.rule == "condition_syntax" && d.error? }
      expect(cond_errors.size).to eq(1)
    end

    it "passes for valid condition syntax" do
      start = build_node("start", shape: "Mdiamond")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "exit" => finish}
      edges = [build_edge("start", "exit", condition: "outcome=success")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      cond_errors = diagnostics.select { |d| d.rule == "condition_syntax" }
      expect(cond_errors).to be_empty
    end

    it "passes for empty condition" do
      diagnostics = validator.validate(valid_pipeline)
      cond_errors = diagnostics.select { |d| d.rule == "condition_syntax" }
      expect(cond_errors).to be_empty
    end
  end

  describe "StylesheetSyntaxRule" do
    it "errors for invalid stylesheet" do
      graph = build_graph(
        nodes: {
          "start" => build_node("start", shape: "Mdiamond"),
          "exit" => build_node("exit", shape: "Msquare")
        },
        edges: [build_edge("start", "exit")],
        attrs: {"model_stylesheet" => "not valid { css }"}
      )

      diagnostics = validator.validate(graph)
      style_errors = diagnostics.select { |d| d.rule == "stylesheet_syntax" && d.error? }
      expect(style_errors.size).to eq(1)
    end

    it "passes for valid stylesheet" do
      graph = build_graph(
        nodes: {
          "start" => build_node("start", shape: "Mdiamond"),
          "exit" => build_node("exit", shape: "Msquare")
        },
        edges: [build_edge("start", "exit")],
        attrs: {"model_stylesheet" => "* { llm_model: claude-opus-4-6; }"}
      )

      diagnostics = validator.validate(graph)
      style_errors = diagnostics.select { |d| d.rule == "stylesheet_syntax" }
      expect(style_errors).to be_empty
    end

    it "passes for empty stylesheet" do
      diagnostics = validator.validate(valid_pipeline)
      style_errors = diagnostics.select { |d| d.rule == "stylesheet_syntax" }
      expect(style_errors).to be_empty
    end
  end

  describe "TypeKnownRule" do
    it "warns for unknown node type" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "unknown_type", prompt: "Do work")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      type_warnings = diagnostics.select { |d| d.rule == "type_known" && d.warning? }
      expect(type_warnings.size).to eq(1)
      expect(type_warnings.first.node_id).to eq("work")
    end

    it "passes for known node types" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      type_warnings = diagnostics.select { |d| d.rule == "type_known" }
      expect(type_warnings).to be_empty
    end

    it "passes for empty type" do
      diagnostics = validator.validate(valid_pipeline)
      type_warnings = diagnostics.select { |d| d.rule == "type_known" }
      expect(type_warnings).to be_empty
    end
  end

  describe "FidelityValidRule" do
    it "warns for invalid node fidelity" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work", fidelity: "bogus")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      fid_warnings = diagnostics.select { |d| d.rule == "fidelity_valid" && d.warning? }
      expect(fid_warnings.size).to eq(1)
    end

    it "warns for invalid edge fidelity" do
      start = build_node("start", shape: "Mdiamond")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "exit" => finish}
      edges = [build_edge("start", "exit", fidelity: "invalid")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      fid_warnings = diagnostics.select { |d| d.rule == "fidelity_valid" && d.warning? }
      expect(fid_warnings.size).to eq(1)
    end

    it "warns for invalid graph default_fidelity" do
      graph = build_graph(
        nodes: {
          "start" => build_node("start", shape: "Mdiamond"),
          "exit" => build_node("exit", shape: "Msquare")
        },
        edges: [build_edge("start", "exit")],
        attrs: {"default_fidelity" => "bad"}
      )

      diagnostics = validator.validate(graph)
      fid_warnings = diagnostics.select { |d| d.rule == "fidelity_valid" && d.warning? }
      expect(fid_warnings.size).to eq(1)
    end

    it "passes for valid fidelity values" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work", fidelity: "compact")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work", fidelity: "full"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges, attrs: {"default_fidelity" => "summary:high"})

      diagnostics = validator.validate(graph)
      fid_warnings = diagnostics.select { |d| d.rule == "fidelity_valid" }
      expect(fid_warnings).to be_empty
    end
  end

  describe "RetryTargetExistsRule" do
    it "warns when node retry_target references non-existent node" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work", retry_target: "missing")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      retry_warnings = diagnostics.select { |d| d.rule == "retry_target_exists" && d.warning? }
      expect(retry_warnings.size).to eq(1)
      expect(retry_warnings.first.message).to include("missing")
    end

    it "warns when graph retry_target references non-existent node" do
      graph = build_graph(
        nodes: {
          "start" => build_node("start", shape: "Mdiamond"),
          "exit" => build_node("exit", shape: "Msquare")
        },
        edges: [build_edge("start", "exit")],
        attrs: {"retry_target" => "ghost"}
      )

      diagnostics = validator.validate(graph)
      retry_warnings = diagnostics.select { |d| d.rule == "retry_target_exists" && d.warning? }
      expect(retry_warnings.size).to eq(1)
    end

    it "passes when retry targets reference existing nodes" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work", retry_target: "start")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      retry_warnings = diagnostics.select { |d| d.rule == "retry_target_exists" }
      expect(retry_warnings).to be_empty
    end
  end

  describe "GoalGateHasRetryRule" do
    it "warns when goal_gate node has no retry target" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work", goal_gate: "true")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      gate_warnings = diagnostics.select { |d| d.rule == "goal_gate_has_retry" && d.warning? }
      expect(gate_warnings.size).to eq(1)
      expect(gate_warnings.first.node_id).to eq("work")
    end

    it "passes when goal_gate node has retry_target" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work",
        goal_gate: "true", retry_target: "start")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      gate_warnings = diagnostics.select { |d| d.rule == "goal_gate_has_retry" }
      expect(gate_warnings).to be_empty
    end

    it "passes when graph has fallback_retry_target" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", prompt: "Do work", goal_gate: "true")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges,
        attrs: {"fallback_retry_target" => "start"})

      diagnostics = validator.validate(graph)
      gate_warnings = diagnostics.select { |d| d.rule == "goal_gate_has_retry" }
      expect(gate_warnings).to be_empty
    end
  end

  describe "PromptOnLlmNodesRule" do
    it "warns when codergen node has no prompt and default label" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      prompt_warnings = diagnostics.select { |d| d.rule == "prompt_on_llm_nodes" && d.warning? }
      expect(prompt_warnings.size).to eq(1)
      expect(prompt_warnings.first.node_id).to eq("work")
    end

    it "passes when codergen node has a prompt" do
      diagnostics = validator.validate(valid_pipeline)
      prompt_warnings = diagnostics.select { |d| d.rule == "prompt_on_llm_nodes" }
      expect(prompt_warnings).to be_empty
    end

    it "passes when codergen node has a custom label" do
      start = build_node("start", shape: "Mdiamond")
      work = build_node("work", type: "codergen", label: "Implement feature")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "work" => work, "exit" => finish}
      edges = [build_edge("start", "work"), build_edge("work", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      prompt_warnings = diagnostics.select { |d| d.rule == "prompt_on_llm_nodes" }
      expect(prompt_warnings).to be_empty
    end

    it "passes for non-codergen nodes without prompt" do
      start = build_node("start", shape: "Mdiamond")
      gate = build_node("gate", type: "wait.human")
      finish = build_node("exit", shape: "Msquare")
      nodes = {"start" => start, "gate" => gate, "exit" => finish}
      edges = [build_edge("start", "gate"), build_edge("gate", "exit")]
      graph = build_graph(nodes: nodes, edges: edges)

      diagnostics = validator.validate(graph)
      prompt_warnings = diagnostics.select { |d| d.rule == "prompt_on_llm_nodes" }
      expect(prompt_warnings).to be_empty
    end
  end
end
