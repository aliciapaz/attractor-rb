# frozen_string_literal: true

module Attractor
  class Edge
    attr_reader :from, :to, :attrs

    def initialize(from, to, attrs = {})
      @from = from
      @to = to
      @attrs = AttributeTypes.coerce_attrs(attrs)
    end

    def label = attrs.fetch("label", "")
    def condition = attrs.fetch("condition", "")
    def weight = attrs.fetch("weight", 0)
    def fidelity = attrs.fetch("fidelity", "")
    def thread_id = attrs.fetch("thread_id", "")
    def loop_restart = attrs.fetch("loop_restart", false)

    def ==(other)
      other.is_a?(Edge) && from == other.from && to == other.to && attrs == other.attrs
    end
  end
end
