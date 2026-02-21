# frozen_string_literal: true

module Attractor
  class Checkpoint
    attr_reader :timestamp, :current_node, :completed_nodes,
      :node_retries, :context_values, :logs, :node_statuses

    def initialize(
      current_node:,
      completed_nodes: [],
      node_retries: {},
      context_values: {},
      logs: [],
      node_statuses: {},
      timestamp: Time.now.iso8601
    )
      @timestamp = timestamp
      @current_node = current_node
      @completed_nodes = completed_nodes
      @node_retries = node_retries
      @context_values = context_values
      @logs = logs
      @node_statuses = node_statuses
    end

    def save(path)
      data = {
        timestamp: timestamp,
        current_node: current_node,
        completed_nodes: completed_nodes,
        node_retries: node_retries,
        context: context_values,
        logs: logs,
        node_statuses: node_statuses
      }
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir)
      tmp = File.join(dir, ".checkpoint.tmp")
      File.write(tmp, JSON.pretty_generate(data))
      FileUtils.mv(tmp, path)
    end

    def self.load(path)
      data = JSON.parse(File.read(path))
      new(
        timestamp: data["timestamp"],
        current_node: data["current_node"],
        completed_nodes: data["completed_nodes"] || [],
        node_retries: data["node_retries"] || {},
        context_values: data["context"] || {},
        logs: data["logs"] || [],
        node_statuses: data["node_statuses"] || {}
      )
    end

    def self.exists?(logs_root)
      File.exist?(checkpoint_path(logs_root))
    end

    def self.checkpoint_path(logs_root)
      File.join(logs_root, "checkpoint.json")
    end
  end
end
