# frozen_string_literal: true

module Attractor
  module AttributeTypes
    DURATION_PATTERN = /\A(-?\d+)(ms|s|m|h|d)\z/

    DURATION_MULTIPLIERS = {
      "ms" => 1,
      "s" => 1000,
      "m" => 60_000,
      "h" => 3_600_000,
      "d" => 86_400_000
    }.freeze

    # Attributes that should be coerced from strings to typed values.
    # All other attributes (label, prompt, condition, etc.) stay as strings.
    TYPED_KEYS = Set.new(%w[
      timeout max_retries goal_gate weight loop_restart allow_partial
      auto_status max_parallel poll_interval max_cycles default_max_retry
    ]).freeze

    def self.coerce(value)
      return value unless value.is_a?(String)

      case value
      when "true" then true
      when "false" then false
      when /\A-?\d+\z/ then value.to_i
      when /\A-?\d*\.\d+\z/ then value.to_f
      when DURATION_PATTERN then parse_duration(value)
      else value
      end
    end

    def self.coerce_attrs(attrs)
      attrs.transform_keys(&:to_s).each_with_object({}) do |(k, v), h|
        h[k] = TYPED_KEYS.include?(k) ? coerce(v) : v
      end
    end

    def self.parse_duration(str)
      match = str.match(DURATION_PATTERN)
      return nil unless match

      amount = match[1].to_i
      unit = match[2]
      amount * DURATION_MULTIPLIERS.fetch(unit)
    end
  end
end
