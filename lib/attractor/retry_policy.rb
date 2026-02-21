# frozen_string_literal: true

module Attractor
  class RetryPolicy
    attr_reader :max_attempts, :backoff

    def initialize(max_attempts:, backoff: Backoff.new)
      @max_attempts = [max_attempts, 1].max
      @backoff = backoff
    end

    def should_retry(error)
      error.is_a?(StandardError) && !error.is_a?(ArgumentError) && !error.is_a?(TypeError)
    end

    def self.none
      new(max_attempts: 1)
    end

    def self.standard
      new(max_attempts: 5, backoff: Backoff.new(initial_delay_ms: 200, backoff_factor: 2.0))
    end

    def self.aggressive
      new(max_attempts: 5, backoff: Backoff.new(initial_delay_ms: 500, backoff_factor: 2.0))
    end

    def self.linear
      new(max_attempts: 3, backoff: Backoff.new(initial_delay_ms: 500, backoff_factor: 1.0))
    end

    def self.patient
      new(max_attempts: 3, backoff: Backoff.new(initial_delay_ms: 2000, backoff_factor: 3.0))
    end

    def self.for_node(node, graph)
      max_attempts = if node.attrs.key?("max_retries")
        node.max_retries + 1
      elsif graph.default_max_retry > 0
        graph.default_max_retry + 1
      else
        1
      end

      new(max_attempts: max_attempts)
    end
  end
end
