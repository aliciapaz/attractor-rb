# frozen_string_literal: true

module Attractor
  module Fidelity
    MODES = %w[full truncate compact summary:low summary:medium summary:high].freeze
    DEFAULT = "compact"

    def self.valid?(mode)
      MODES.include?(mode)
    end

    def self.resolve(edge: nil, node: nil, graph: nil)
      mode = edge_fidelity(edge) ||
        node_fidelity(node) ||
        graph_fidelity(graph) ||
        DEFAULT

      valid?(mode) ? mode : DEFAULT
    end

    def self.edge_fidelity(edge)
      return nil unless edge
      f = edge.fidelity
      f.empty? ? nil : f
    end

    def self.node_fidelity(node)
      return nil unless node
      f = node.fidelity
      f.empty? ? nil : f
    end

    def self.graph_fidelity(graph)
      return nil unless graph
      f = graph.default_fidelity
      f.empty? ? nil : f
    end
  end
end
