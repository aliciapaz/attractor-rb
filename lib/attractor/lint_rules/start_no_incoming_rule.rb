# frozen_string_literal: true

module Attractor
  module LintRules
    class StartNoIncomingRule < BaseRule
      def name
        "start_no_incoming"
      end

      def apply(graph)
        start = graph.start_node
        return [] unless start

        incoming = graph.incoming_edges(start.id)
        return [] if incoming.empty?

        sources = incoming.map(&:from).join(", ")
        [
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_ERROR,
            message: "Start node '#{start.id}' has incoming edges from: #{sources}",
            node_id: start.id,
            fix: "Remove incoming edges to the start node"
          )
        ]
      end
    end
  end
end
