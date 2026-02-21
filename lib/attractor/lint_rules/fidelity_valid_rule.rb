# frozen_string_literal: true

module Attractor
  module LintRules
    class FidelityValidRule < BaseRule
      def name
        "fidelity_valid"
      end

      def apply(graph)
        diagnostics = []
        diagnostics.concat(check_graph_fidelity(graph))
        diagnostics.concat(check_node_fidelity(graph))
        diagnostics.concat(check_edge_fidelity(graph))
        diagnostics
      end

      private

      def check_graph_fidelity(graph)
        fidelity = graph.default_fidelity
        return [] if fidelity.empty?
        return [] if Fidelity.valid?(fidelity)

        [
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_WARNING,
            message: "Graph default_fidelity '#{fidelity}' is not a valid fidelity mode",
            fix: "Use one of: #{Fidelity::MODES.join(", ")}"
          )
        ]
      end

      def check_node_fidelity(graph)
        graph.nodes.values.filter_map do |node|
          fidelity = node.fidelity
          next if fidelity.empty?
          next if Fidelity.valid?(fidelity)

          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_WARNING,
            message: "Node '#{node.id}' has invalid fidelity '#{fidelity}'",
            node_id: node.id,
            fix: "Use one of: #{Fidelity::MODES.join(", ")}"
          )
        end
      end

      def check_edge_fidelity(graph)
        graph.edges.filter_map do |edge|
          fidelity = edge.fidelity
          next if fidelity.empty?
          next if Fidelity.valid?(fidelity)

          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_WARNING,
            message: "Edge #{edge.from} -> #{edge.to} has invalid fidelity '#{fidelity}'",
            edge: [edge.from, edge.to],
            fix: "Use one of: #{Fidelity::MODES.join(", ")}"
          )
        end
      end
    end
  end
end
