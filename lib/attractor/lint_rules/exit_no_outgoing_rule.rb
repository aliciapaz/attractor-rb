# frozen_string_literal: true

module Attractor
  module LintRules
    class ExitNoOutgoingRule < BaseRule
      def name
        "exit_no_outgoing"
      end

      def apply(graph)
        graph.exit_nodes.flat_map do |exit_node|
          outgoing = graph.outgoing_edges(exit_node.id)
          next [] if outgoing.empty?

          targets = outgoing.map(&:to).join(", ")
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_ERROR,
            message: "Exit node '#{exit_node.id}' has outgoing edges to: #{targets}",
            node_id: exit_node.id,
            fix: "Remove outgoing edges from the exit node"
          )
        end
      end
    end
  end
end
