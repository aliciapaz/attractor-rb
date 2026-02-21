# frozen_string_literal: true

module Attractor
  class Graph
    attr_reader :name, :nodes, :edges, :attrs

    def initialize(name, nodes: {}, edges: [], attrs: {})
      @name = name
      @nodes = nodes
      @edges = edges
      @attrs = AttributeTypes.coerce_attrs(attrs)
    end

    def goal = attrs.fetch("goal", "")
    def label = attrs.fetch("label", "")
    def model_stylesheet = attrs.fetch("model_stylesheet", "")
    def default_max_retry = attrs.fetch("default_max_retry", 0)
    def retry_target = attrs.fetch("retry_target", "")
    def fallback_retry_target = attrs.fetch("fallback_retry_target", "")
    def default_fidelity = attrs.fetch("default_fidelity", "")

    def add_node(node)
      @nodes[node.id] = node
    end

    def add_edge(edge)
      @edges << edge
    end

    def outgoing_edges(node_id)
      edges.select { |e| e.from == node_id }
    end

    def incoming_edges(node_id)
      edges.select { |e| e.to == node_id }
    end

    def start_node
      @nodes.values.find(&:start?) ||
        @nodes["start"] ||
        @nodes["Start"]
    end

    def exit_node
      @nodes.values.find(&:exit?) ||
        @nodes["exit"] ||
        @nodes["end"]
    end

    def start_nodes
      @nodes.values.select(&:start?)
    end

    def exit_nodes
      @nodes.values.select(&:exit?)
    end
  end
end
