# frozen_string_literal: true

module Attractor
  class Backoff
    attr_reader :initial_delay_ms, :backoff_factor, :max_delay_ms, :jitter

    def initialize(initial_delay_ms: 200, backoff_factor: 2.0, max_delay_ms: 60_000, jitter: true)
      @initial_delay_ms = initial_delay_ms
      @backoff_factor = backoff_factor
      @max_delay_ms = max_delay_ms
      @jitter = jitter
    end

    def delay_for_attempt(attempt)
      delay = initial_delay_ms * (backoff_factor**(attempt - 1))
      delay = [delay, max_delay_ms].min
      delay *= rand(0.5..1.5) if jitter
      delay.round
    end
  end
end
