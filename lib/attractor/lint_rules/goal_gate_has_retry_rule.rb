# frozen_string_literal: true

module Attractor
  module LintRules
    class GoalGateHasRetryRule < BaseRule
      def name
        "goal_gate_has_retry"
      end

      def apply(graph)
        graph.nodes.values.filter_map do |node|
          next unless node.goal_gate == true
          next if has_retry_target?(node)
          next if has_graph_retry_target?(graph)

          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_WARNING,
            message: "Node '#{node.id}' has goal_gate=true but no retry_target or fallback_retry_target",
            node_id: node.id,
            fix: "Add retry_target or fallback_retry_target to the node or graph"
          )
        end
      end

      private

      def has_retry_target?(node)
        !node.retry_target.to_s.empty? || !node.fallback_retry_target.to_s.empty?
      end

      def has_graph_retry_target?(graph)
        !graph.retry_target.to_s.empty? || !graph.fallback_retry_target.to_s.empty?
      end
    end
  end
end
