# frozen_string_literal: true

module Attractor
  module LintRules
    class StartNodeRule < BaseRule
      def name
        "start_node"
      end

      def apply(graph)
        start_nodes = graph.nodes.values.select(&:start?)
        return start_node_missing_diagnostic if start_nodes.empty?
        return multiple_start_diagnostics(start_nodes) if start_nodes.size > 1

        []
      end

      private

      def start_node_missing_diagnostic
        [
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_ERROR,
            message: "Pipeline must have exactly one start node (shape=Mdiamond)",
            fix: "Add a node with shape=Mdiamond"
          )
        ]
      end

      def multiple_start_diagnostics(start_nodes)
        ids = start_nodes.map(&:id).join(", ")
        [
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_ERROR,
            message: "Pipeline has #{start_nodes.size} start nodes (#{ids}), expected exactly 1",
            fix: "Remove extra start nodes so only one has shape=Mdiamond"
          )
        ]
      end
    end
  end
end
