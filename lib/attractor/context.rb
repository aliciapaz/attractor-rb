# frozen_string_literal: true

require "concurrent"

module Attractor
  class Context
    def initialize(values: {}, logs: [])
      @values = values.dup
      @logs = logs.dup
      @lock = Concurrent::ReadWriteLock.new
    end

    def set(key, value)
      @lock.with_write_lock { @values[key] = value }
    end

    def get(key, default = nil)
      @lock.with_read_lock { @values.fetch(key, default) }
    end

    def get_string(key, default = "")
      value = get(key)
      value.nil? ? default : value.to_s
    end

    def append_log(entry)
      @lock.with_write_lock { @logs << entry }
    end

    def snapshot
      @lock.with_read_lock { @values.dup }
    end

    def logs
      @lock.with_read_lock { @logs.dup }
    end

    def clone
      @lock.with_read_lock do
        deep_values = Marshal.load(Marshal.dump(@values))
        Context.new(values: deep_values, logs: @logs.dup)
      end
    end

    def apply_updates(updates)
      @lock.with_write_lock do
        updates.each { |k, v| @values[k] = v }
      end
    end
  end
end
