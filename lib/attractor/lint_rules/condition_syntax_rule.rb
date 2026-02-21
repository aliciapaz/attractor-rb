# frozen_string_literal: true

module Attractor
  module LintRules
    class ConditionSyntaxRule < BaseRule
      def name
        "condition_syntax"
      end

      def apply(graph)
        graph.edges.filter_map do |edge|
          condition = edge.condition
          next if condition.is_a?(String) && condition.empty?
          next if Condition::Parser.valid?(condition.to_s)

          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_ERROR,
            message: "Edge #{edge.from} -> #{edge.to} has invalid condition syntax: '#{condition}'",
            edge: [edge.from, edge.to],
            fix: "Fix the condition expression to use valid syntax: key=value, key!=value, joined with &&"
          )
        end
      end
    end
  end
end
