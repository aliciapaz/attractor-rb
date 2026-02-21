# frozen_string_literal: true

module Attractor
  module LintRules
    class RetryTargetExistsRule < BaseRule
      def name
        "retry_target_exists"
      end

      def apply(graph)
        diagnostics = []
        diagnostics.concat(check_node_targets(graph))
        diagnostics.concat(check_graph_targets(graph))
        diagnostics
      end

      private

      def check_node_targets(graph)
        graph.nodes.values.flat_map do |node|
          check_target(graph, node.retry_target, "retry_target", node.id) +
            check_target(graph, node.fallback_retry_target, "fallback_retry_target", node.id)
        end
      end

      def check_graph_targets(graph)
        check_target(graph, graph.retry_target, "graph retry_target") +
          check_target(graph, graph.fallback_retry_target, "graph fallback_retry_target")
      end

      def check_target(graph, target, attr_name, node_id = nil)
        return [] if target.is_a?(String) && target.empty?
        return [] if graph.nodes.key?(target.to_s)

        message = if node_id
          "Node '#{node_id}' #{attr_name} references non-existent node '#{target}'"
        else
          "Graph #{attr_name} references non-existent node '#{target}'"
        end

        [
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_WARNING,
            message: message,
            node_id: node_id,
            fix: "Add node '#{target}' or fix the #{attr_name} reference"
          )
        ]
      end
    end
  end
end
