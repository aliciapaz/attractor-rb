# frozen_string_literal: true

module Attractor
  module LintRules
    class PromptOnLlmNodesRule < BaseRule
      LLM_TYPES = %w[codergen].freeze

      def name
        "prompt_on_llm_nodes"
      end

      def apply(graph)
        graph.nodes.values.filter_map do |node|
          next unless resolves_to_llm?(node)
          next unless node.prompt.to_s.empty?
          next unless node.label == node.id

          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_WARNING,
            message: "LLM node '#{node.id}' has no prompt and label is the default (node ID)",
            node_id: node.id,
            fix: "Add a prompt attribute or a descriptive label to guide the LLM"
          )
        end
      end

      private

      def resolves_to_llm?(node)
        LLM_TYPES.include?(node.type)
      end
    end
  end
end
