# frozen_string_literal: true

module Attractor
  class GoalGateChecker
    def check(graph, node_outcomes)
      graph.nodes.each_value do |node|
        next unless node.goal_gate

        outcome = node_outcomes[node.id]
        next if outcome&.success?

        return [false, node]
      end

      [true, nil]
    end

    def retry_target(node, graph)
      target = node.retry_target
      return target unless target.empty?

      target = node.fallback_retry_target
      return target unless target.empty?

      target = graph.retry_target
      return target unless target.empty?

      target = graph.fallback_retry_target
      return target unless target.empty?

      nil
    end
  end
end
