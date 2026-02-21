# frozen_string_literal: true

module Attractor
  class Diagnostic
    SEVERITY_ERROR = :error
    SEVERITY_WARNING = :warning
    SEVERITY_INFO = :info

    attr_reader :rule, :severity, :message, :node_id, :edge, :fix

    def initialize(rule:, severity:, message:, node_id: nil, edge: nil, fix: nil)
      @rule = rule
      @severity = severity
      @message = message
      @node_id = node_id
      @edge = edge
      @fix = fix
    end

    def error? = severity == SEVERITY_ERROR
    def warning? = severity == SEVERITY_WARNING
    def info? = severity == SEVERITY_INFO
  end
end
