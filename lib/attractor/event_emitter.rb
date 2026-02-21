# frozen_string_literal: true

module Attractor
  class EventEmitter
    def initialize
      @listeners = []
    end

    def on_event(&block)
      @listeners << block
    end

    def emit(event)
      @listeners.each do |listener|
        listener.call(event)
      rescue => e
        warn "EventEmitter: listener raised #{e.class}: #{e.message}"
      end
    end
  end
end
