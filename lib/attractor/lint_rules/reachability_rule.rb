# frozen_string_literal: true

module Attractor
  module LintRules
    class ReachabilityRule < BaseRule
      def name
        "reachability"
      end

      def apply(graph)
        start = graph.start_node
        return [] unless start

        reachable = bfs(graph, start.id)
        unreachable = graph.nodes.keys - reachable

        unreachable.map do |node_id|
          Diagnostic.new(
            rule: name,
            severity: Diagnostic::SEVERITY_ERROR,
            message: "Node '#{node_id}' is not reachable from the start node",
            node_id: node_id,
            fix: "Add an edge path from the start node to '#{node_id}'"
          )
        end
      end

      private

      def bfs(graph, start_id)
        visited = Set.new([start_id])
        queue = [start_id]

        until queue.empty?
          current = queue.shift
          graph.outgoing_edges(current).each do |edge|
            next if visited.include?(edge.to)

            visited.add(edge.to)
            queue.push(edge.to)
          end
        end

        visited.to_a
      end
    end
  end
end
