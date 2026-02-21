# frozen_string_literal: true

module Attractor
  module LintRules
    class TerminalNodeRule < BaseRule
      def name
        "terminal_node"
      end

      def apply(graph)
        exit_nodes = graph.nodes.values.select(&:exit?)
        return [] unless exit_nodes.empty?

        [
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_ERROR,
            message: "Pipeline must have at least one terminal node (shape=Msquare)",
            fix: "Add a node with shape=Msquare"
          )
        ]
      end
    end
  end
end
