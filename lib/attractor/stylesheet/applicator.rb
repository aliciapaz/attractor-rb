# frozen_string_literal: true

module Attractor
  module Stylesheet
    class Applicator
      STYLESHEET_PROPERTIES = %w[llm_model llm_provider reasoning_effort].freeze

      def apply(graph)
        source = graph.model_stylesheet
        return graph if source.to_s.strip.empty?

        rules = Parser.parse(source)
        sorted_rules = rules.sort_by(&:specificity)

        graph.nodes.each_value do |node|
          apply_rules_to_node(node, sorted_rules)
        end

        graph
      end

      private

      def apply_rules_to_node(node, rules)
        # Collect explicit (pre-existing) attrs to protect from override
        explicit = node.attrs.select { |k, v| STYLESHEET_PROPERTIES.include?(k) && !v.to_s.empty? }

        # Apply rules in specificity order (ascending). Higher specificity overwrites lower.
        rules.each do |rule|
          next unless rule.matches?(node)

          rule.declarations.each do |property, value|
            next unless STYLESHEET_PROPERTIES.include?(property)
            next if explicit.key?(property)

            node.set_attr(property, value)
          end
        end
      end
    end
  end
end
