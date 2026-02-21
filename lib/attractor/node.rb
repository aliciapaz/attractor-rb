# frozen_string_literal: true

module Attractor
  class Node
    attr_reader :id, :attrs

    def initialize(id, attrs = {})
      @id = id
      @attrs = AttributeTypes.coerce_attrs(attrs)
    end

    def label = attrs.fetch("label", id)
    def shape = attrs.fetch("shape", "box")
    def type = attrs.fetch("type", "")
    def prompt = attrs.fetch("prompt", "")
    def max_retries = attrs.fetch("max_retries", 0)
    def goal_gate = attrs.fetch("goal_gate", false)
    def retry_target = attrs.fetch("retry_target", "")
    def fallback_retry_target = attrs.fetch("fallback_retry_target", "")
    def fidelity = attrs.fetch("fidelity", "")
    def thread_id = attrs.fetch("thread_id", "")
    def node_class = attrs.fetch("class", "")
    def timeout = attrs.fetch("timeout", nil)
    def allow_partial = attrs.fetch("allow_partial", false)
    def auto_status = attrs.fetch("auto_status", false)

    def classes
      node_class.to_s.split(",").map(&:strip).reject(&:empty?)
    end

    def start? = shape == "Mdiamond"
    def exit? = shape == "Msquare"

    def merge_attrs(new_attrs)
      merged = attrs.merge(new_attrs) { |_k, old, new_val| (old == "" || old.nil?) ? new_val : old }
      Node.new(id, merged)
    end

    def set_attr(key, value)
      @attrs[key] = AttributeTypes::TYPED_KEYS.include?(key) ? AttributeTypes.coerce(value) : value
    end

    def ==(other)
      other.is_a?(Node) && id == other.id
    end

    def hash = id.hash
    def eql?(other) = self == other
  end
end
