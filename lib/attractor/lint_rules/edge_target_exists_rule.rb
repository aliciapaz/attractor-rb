# frozen_string_literal: true

module Attractor
  module LintRules
    class EdgeTargetExistsRule < BaseRule
      def name
        "edge_target_exists"
      end

      def apply(graph)
        diagnostics = []

        graph.edges.each do |edge|
          unless graph.nodes.key?(edge.from)
            diagnostics << Diagnostic.new(
              rule: name,
              severity: Diagnostic::SEVERITY_ERROR,
              message: "Edge references non-existent source node '#{edge.from}'",
              edge: [edge.from, edge.to],
              fix: "Add node '#{edge.from}' or fix the edge source"
            )
          end

          unless graph.nodes.key?(edge.to)
            diagnostics << Diagnostic.new(
              rule: name,
              severity: Diagnostic::SEVERITY_ERROR,
              message: "Edge references non-existent target node '#{edge.to}'",
              edge: [edge.from, edge.to],
              fix: "Add node '#{edge.to}' or fix the edge target"
            )
          end
        end

        diagnostics
      end
    end
  end
end
