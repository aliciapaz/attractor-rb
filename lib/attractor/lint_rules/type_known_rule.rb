# frozen_string_literal: true

module Attractor
  module LintRules
    class TypeKnownRule < BaseRule
      KNOWN_TYPES = %w[
        start exit codergen wait.human conditional
        parallel parallel.fan_in tool stack.manager_loop
      ].freeze

      def name
        "type_known"
      end

      def apply(graph)
        graph.nodes.values.filter_map do |node|
          node_type = node.type
          next if node_type.empty?
          next if KNOWN_TYPES.include?(node_type)

          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_WARNING,
            message: "Node '#{node.id}' has unknown type '#{node_type}'",
            node_id: node.id,
            fix: "Use a known type: #{KNOWN_TYPES.join(", ")}"
          )
        end
      end
    end
  end
end
