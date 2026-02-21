# frozen_string_literal: true

module Attractor
  module Transforms
    class VariableExpansion < BaseTransform
      def apply(graph)
        goal = graph.goal
        return graph if goal.empty?

        graph.nodes.each_value do |node|
          next if node.prompt.empty?
          next unless node.prompt.include?("$goal")

          node.set_attr("prompt", node.prompt.gsub("$goal", goal))
        end

        graph
      end
    end
  end
end
